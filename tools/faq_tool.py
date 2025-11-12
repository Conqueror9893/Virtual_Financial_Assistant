#tools/faq_tool.py

import os
import fitz  # PyMuPDF
import docx
import pandas as pd
from typing import List, Dict
from utils.logger import get_logger
from utils.llm_connector import run_llm
from sentence_transformers import SentenceTransformer
import chromadb

logger = get_logger("FAQTool")

DATA_FOLDER = "data/faqs"  # folder containing all FAQ documents
CHROMA_PATH = "data/chroma_faq_db"
COLLECTION_NAME = "banking_faqs"
EMBEDDING_MODEL = "all-MiniLM-L6-v2"

# ------------------ HELPERS ------------------ #

def extract_text_from_pdf(path: str) -> List[Dict[str, str]]:
    """Extract text per page & paragraph from a PDF file."""
    results = []
    try:
        doc = fitz.open(path)
        for page_num, page in enumerate(doc, start=1):
            text = page.get_text("text")
            paragraphs = [p.strip() for p in text.split("\n") if p.strip()]
            for idx, para in enumerate(paragraphs):
                snippet = para[:200].replace("\n", " ")
                results.append({
                    "text": para,
                    "file": os.path.basename(path),
                    "page": page_num,
                    "para": idx + 1,
                    "snippet": snippet,
                    "source_path": path,
                })
        doc.close()
    except Exception as e:
        logger.exception(f"Error reading PDF {path}: {e}")
    return results


def extract_text_from_docx(path: str) -> List[Dict[str, str]]:
    """Extract text paragraphs from a Word file."""
    results = []
    try:
        doc = docx.Document(path)
        for idx, para in enumerate(doc.paragraphs):
            text = para.text.strip()
            if not text:
                continue
            snippet = text[:200].replace("\n", " ")
            results.append({
                "text": text,
                "file": os.path.basename(path),
                "page": None,
                "para": idx + 1,
                "snippet": snippet,
                "source_path": path,
            })
    except Exception as e:
        logger.exception(f"Error reading DOCX {path}: {e}")
    return results


def extract_text_from_excel(path: str) -> List[Dict[str, str]]:
    """Extract text from Excel files (all sheets)."""
    results = []
    try:
        xls = pd.ExcelFile(path)
        for sheet_name in xls.sheet_names:
            df = pd.read_excel(xls, sheet_name=sheet_name)
            for row_idx, row in df.iterrows():
                row_text = " | ".join([str(v) for v in row if pd.notna(v)])
                if not row_text.strip():
                    continue
                snippet = row_text[:200].replace("\n", " ")
                results.append({
                    "text": row_text,
                    "file": f"{os.path.basename(path)}:{sheet_name}",
                    "page": None,
                    "para": row_idx + 1,
                    "snippet": snippet,
                    "source_path": path,
                })
    except Exception as e:
        logger.exception(f"Error reading Excel {path}: {e}")
    return results


def load_all_documents() -> List[Dict[str, str]]:
    """Load and extract text chunks from all supported files in folder."""
    supported_ext = {".pdf", ".docx", ".xlsx"}
    all_chunks = []
    for root, _, files in os.walk(DATA_FOLDER):
        for file in files:
            ext = os.path.splitext(file)[1].lower()
            full_path = os.path.join(root, file)
            if ext not in supported_ext:
                continue
            if ext == ".pdf":
                all_chunks.extend(extract_text_from_pdf(full_path))
            elif ext == ".docx":
                all_chunks.extend(extract_text_from_docx(full_path))
            elif ext == ".xlsx":
                all_chunks.extend(extract_text_from_excel(full_path))
    logger.info("Extracted %d total text chunks from documents.", len(all_chunks))
    return all_chunks


# ------------------ CHROMADB SETUP ------------------ #

def get_chroma_collection():
    client = chromadb.PersistentClient(path=CHROMA_PATH)
    if COLLECTION_NAME not in [c.name for c in client.list_collections()]:
        collection = client.create_collection(name=COLLECTION_NAME, metadata={"source": "faq_docs"})
        logger.info("Created new ChromaDB collection: %s", COLLECTION_NAME)
    else:
        collection = client.get_collection(COLLECTION_NAME)
    return collection


def build_vector_store():
    """Embed and store all documents in ChromaDB."""
    logger.info("Building ChromaDB vector store from documents...")
    chunks = load_all_documents()
    if not chunks:
        raise ValueError("No documents found in FAQ data folder.")

    model = SentenceTransformer(EMBEDDING_MODEL)
    collection = get_chroma_collection()
    # Clear old data safely
    try:
        existing = collection.get()
        if existing and len(existing["ids"]) > 0:
            collection.delete(ids=existing["ids"])
            logger.info(f"Cleared {len(existing['ids'])} old items from Chroma collection.")
    except Exception as e:
        logger.warning(f"Could not clear existing data: {e}")

    embeddings = model.encode([c["text"] for c in chunks], convert_to_numpy=True).tolist()
    # ✅ Prepare clean metadata — Chroma only accepts str, int, float, bool
    metadatas = []
    for c in chunks:
        metadatas.append({
            "file": str(c.get("file") or ""),
            "page": int(c.get("page") or 0),
            "para": int(c.get("para") or 0),
            "snippet": str(c.get("snippet") or ""),
            "source_path": str(c.get("source_path") or ""),
        })

    collection.add(
        ids=[f"doc_{i}" for i in range(len(chunks))],
        embeddings=embeddings,
        documents=[c["text"] for c in chunks],
        metadatas=metadatas,
    )


    logger.info("Vector store built successfully with %d entries.", len(chunks))
    return collection


def ensure_vector_store():
    """
    Ensure ChromaDB is built at least once.
    Called manually before first use or after adding new docs.
    """
    collection = get_chroma_collection()
    if collection.count() == 0:
        logger.info("No existing embeddings found. Building vector store...")
        build_vector_store()
    else:
        logger.info("ChromaDB already populated with %d entries.", collection.count())


# ------------------ RETRIEVAL ------------------ #

def search_faq(query: str) -> Dict[str, str]:
    """Search all stored docs, return top-2 relevant answers with source snippets."""
    model = SentenceTransformer(EMBEDDING_MODEL)
    collection = get_chroma_collection()

    if collection.count() == 0:
        logger.info("FAQ vector DB empty, rebuilding...")
        collection = build_vector_store()

    query_emb = model.encode([query], convert_to_numpy=True).tolist()

    results = collection.query(
        query_embeddings=query_emb,
        n_results=2,
        include=["documents", "metadatas", "distances"],
    )

    if not results["documents"] or not results["documents"][0]:
        return {
            "answer": "No relevant information found.",
            "confidence": 0.0,
            "sources": [],
        }

    sources = []
    for i in range(min(2, len(results["documents"][0]))):
        meta = results["metadatas"][0][i]
        distance = results["distances"][0][i]
        confidence = round(1 - distance, 3)
        source_link = meta["source_path"]
        page_info = f"(page {meta['page']})" if meta["page"] else ""
        snippet = meta["snippet"]
        sources.append({
            "file": meta["file"],
            "link": source_link,
            "page": meta["page"],
            "para": meta["para"],
            "snippet": snippet,
            "confidence": confidence
        })

    # Summarize best answer using LLM, grounded in retrieved snippets
    context = "\n\n".join([s["snippet"] for s in sources])
    prompt = f"""
    You are a helpful and concise banking FAQ assistant.
    The user asked: "{query}".
    Based strictly on the information provided below, give a clear and direct answer.
    Do NOT mention documents, sources, file names, or any references. Do NOT provide document names or links.
    Only provide the factual answer.

    Context:
    {context}

    Return only the answer, without repeating the question.
    """
    logger.info("Generating answer with LLM for query: %s", query)
    logger.debug("LLM Prompt: %s", prompt)
    logger.debug("Context used for LLM: %s", context)
    logger.debug("Sources: %s", sources)

    llm_answer = run_llm(prompt).strip()
    top_conf = sources[0]["confidence"]
    logger.info("LLM Answer: %s", llm_answer)
    logger.info("Top confidence score: %.3f", top_conf)
    logger.info("Sources used: %s", sources)
    return {
        "answer": llm_answer,
        "confidence": top_conf,
        "sources": sources
    }
