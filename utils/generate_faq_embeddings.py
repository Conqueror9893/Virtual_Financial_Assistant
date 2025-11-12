# generate_faq_embeddings.py
from tools.faq_tool import ensure_vector_store

if __name__ == "__main__":
    print("🔍 Checking FAQ embeddings...")
    ensure_vector_store()
    print("✅ Vector store ready!")

    # Optional: force rebuild if you’ve added new or updated files
    # print("Rebuilding embeddings from scratch...")
    # build_vector_store()
    # print("✅ Embeddings regenerated successfully.")