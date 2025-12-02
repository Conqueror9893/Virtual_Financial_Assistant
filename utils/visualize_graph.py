# scripts/visualize_main_flow.py
import os
import sys
import importlib

# adjust PYTHONPATH so your package can be imported if needed
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

# import the builder
from langgraph_flow.flows.main_flow import build_main_flow
from langgraph_flow.flows.transfer_flow import build_transfer_flow

def ensure_graphviz_on_path():
    graphviz_bin = r"C:\Program Files\Graphviz\bin"
    if os.path.exists(graphviz_bin):
        os.environ["PATH"] = graphviz_bin + os.pathsep + os.environ.get("PATH", "")
        print("✅ Graphviz PATH configured")

def save_png(drawable, outpath):
    data = drawable.draw_png()
    if not isinstance(data, (bytes, bytearray)):
        raise RuntimeError("draw_png() did not return bytes")
    with open(outpath, "wb") as f:
        f.write(data)
    print(f"✅ PNG written to {outpath}")

def save_mermaid(drawable, outpath):
    text = drawable.draw_mermaid()
    with open(outpath, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"✅ Mermaid text written to {outpath} (open with mermaid.live)")

def main():
    ensure_graphviz_on_path()

    compiled = build_main_flow()            # compiled graph instance
    # quick introspection
    print("Compiled graph type:", type(compiled))
    if not hasattr(compiled, "get_graph"):
        print("❌ Compiled graph does not expose get_graph(). Inspect available attrs:")
        print(sorted([n for n in dir(compiled) if not n.startswith("_")])[:200])
        return

    drawable = compiled.get_graph()
    out_dir = os.path.join(os.path.dirname(__file__), "..", "artifacts")
    os.makedirs(out_dir, exist_ok=True)

    png_path = os.path.join(out_dir, "main_flow.png")
    mermaid_path = os.path.join(out_dir, "main_flow.mmd")

    # try png first, then mermaid fallback
    try:
        save_png(drawable, png_path)
        return
    except Exception as e:
        print(f"⚠ PNG generation failed: {e}")

    try:
        # some versions provide draw_mermaid_png or draw_mermaid
        if hasattr(drawable, "draw_mermaid_png"):
            data = drawable.draw_mermaid_png()
            if isinstance(data, (bytes, bytearray)):
                with open(png_path, "wb") as f:
                    f.write(data)
                print(f"✅ Mermaid PNG written to {png_path}")
                return

        if hasattr(drawable, "draw_mermaid"):
            save_mermaid(drawable, mermaid_path)
            return

    except Exception as e:
        print(f"⚠ Mermaid fallback failed: {e}")

    print("❌ No drawable output produced. Check LangGraph version and installed packages.")

if __name__ == "__main__":
    main()
