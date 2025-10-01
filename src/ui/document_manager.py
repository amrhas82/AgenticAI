import streamlit as st
from datetime import datetime


class DocumentManager:
    """Enhanced document management UI for Streamlit"""
    
    def __init__(self, vector_db, doc_processor):
        self.vector_db = vector_db
        self.doc_processor = doc_processor
    
    def render_document_sidebar(self):
        """Render document management section in sidebar"""
        st.subheader("📄 Document Library")
        
        # Get document statistics
        stats = self.vector_db.get_document_stats()
        col1, col2 = st.columns(2)
        with col1:
            st.metric("Documents", stats.get("total_documents", 0))
        with col2:
            st.metric("Chunks", stats.get("total_chunks", 0))
        
        # Document list with management
        documents = self.vector_db.list_documents()
        
        if documents:
            st.write("**Uploaded Documents:**")
            for doc in documents:
                with st.expander(f"📄 {doc['name']}"):
                    st.write(f"Chunks: {doc['chunks']}")
                    if doc.get('last_updated'):
                        updated = doc['last_updated'][:19]  # Trim to readable format
                        st.write(f"Updated: {updated}")
                    
                    col1, col2 = st.columns(2)
                    with col1:
                        if st.button(f"🔍 Search", key=f"search_{doc['name']}"):
                            st.session_state['search_filter'] = doc['name']
                    with col2:
                        if st.button(f"🗑️ Delete", key=f"del_{doc['name']}"):
                            if self.vector_db.delete_document(doc['name']):
                                st.success(f"Deleted {doc['name']}")
                                st.rerun()
                            else:
                                st.error("Delete failed")
        else:
            st.info("No documents uploaded yet")
        
        # Upload new document
        st.divider()
        st.write("**Upload New Document:**")
        uploaded_file = st.file_uploader(
            "Choose file",
            type=["pdf", "txt", "md", "docx"],
            key="doc_uploader"
        )
        
        # Processing options
        with st.expander("⚙️ Processing Options"):
            chunk_size = st.slider(
                "Chunk size (words)",
                min_value=200,
                max_value=2000,
                value=1000,
                step=100
            )
            chunk_overlap = st.slider(
                "Chunk overlap (words)",
                min_value=0,
                max_value=500,
                value=200,
                step=50
            )
        
        if uploaded_file is not None:
            if st.button("📤 Process & Upload", type="primary"):
                self._process_and_upload(
                    uploaded_file,
                    chunk_size,
                    chunk_overlap
                )
    
    def render_document_explorer(self):
        """Render full-page document explorer"""
        st.title("📚 Document Explorer")
        
        # Get all documents
        documents = self.vector_db.list_documents()
        
        if not documents:
            st.info("No documents in the library. Upload documents via the sidebar!")
            return
        
        # Create tabs for different views
        tab1, tab2, tab3 = st.tabs(["📋 Overview", "🔍 Search", "📊 Analytics"])
        
        with tab1:
            self._render_overview(documents)
        
        with tab2:
            self._render_search_interface()
        
        with tab3:
            self._render_analytics(documents)
    
    def _process_and_upload(
        self,
        uploaded_file,
        chunk_size: int,
        chunk_overlap: int
    ):
        """Process and upload a document with progress tracking"""
        with st.spinner("Processing document..."):
            try:
                name = getattr(uploaded_file, 'name', 'uploaded')
                
                # Progress bar
                progress_bar = st.progress(0)
                status_text = st.empty()
                
                # Extract text
                status_text.text("Extracting text...")
                progress_bar.progress(25)
                
                # Update processor settings
                self.doc_processor.chunk_size = chunk_size
                self.doc_processor.chunk_overlap = chunk_overlap
                
                # Process the file based on type
                chunks = self.doc_processor.process_file(uploaded_file, name)
                
                if not chunks:
                    st.warning("No content extracted from the document.")
                    return
                
                # Create metadata
                metadata = {
                    "file_type": name.split('.')[-1],
                    "chunk_size": chunk_size,
                    "chunk_overlap": chunk_overlap,
                    "upload_time": datetime.now().isoformat()
                }
                
                # Store in vector DB
                status_text.text(f"Storing {len(chunks)} chunks...")
                progress_bar.progress(50)
                
                self.vector_db.store_document(chunks, name, metadata)
                
                progress_bar.progress(100)
                status_text.text("Complete!")
                st.success(f"✅ Successfully uploaded {name}")
                
            except Exception as e:
                st.error(f"❌ Error processing document: {e}")

    def _render_overview(self, documents):
        """Show a simple overview table of uploaded documents"""
        try:
            # Normalize rows
            rows = []
            for doc in documents:
                rows.append({
                    "name": doc.get("name", "unknown"),
                    "chunks": doc.get("chunks", 0),
                    "last_updated": (doc.get("last_updated") or "")[:19]
                })
            st.dataframe(rows, use_container_width=True)
        except Exception as e:
            st.warning(f"Unable to render overview: {e}")

    def _render_search_interface(self):
        """Interactive search UI for vector database"""
        query = st.text_input("Search query", placeholder="Enter keywords or a question...")
        limit = st.slider("Results", min_value=1, max_value=20, value=5)

        # Optional filter by document name
        try:
            documents = self.vector_db.list_documents()
            doc_names = [d.get("name") for d in documents]
        except Exception:
            doc_names = []

        filter_doc = st.selectbox(
            "Filter by document (optional)",
            options=["All"] + doc_names,
            index=0
        )

        if st.button("🔍 Run Search", type="primary") and query.strip():
            filters = None
            if filter_doc and filter_doc != "All":
                filters = {"document_name": filter_doc}

            try:
                results = self.vector_db.search_similar(query, limit=limit, filters=filters, rerank=True)
            except TypeError:
                # Fallback for basic VectorDB without filters/rerank
                results = self.vector_db.search_similar(query, limit=limit)

            if not results:
                st.info("No matches found.")
                return

            # Render results (support both EnhancedVectorDB and VectorDB outputs)
            if isinstance(results[0], dict):
                for idx, item in enumerate(results, start=1):
                    st.markdown(f"**{idx}. (score: {item.get('score', 0):.3f})**")
                    st.write(item.get("chunk_text", ""))
                    meta = item.get("metadata", {})
                    if meta:
                        with st.expander("Metadata"):
                            st.json(meta)
                    st.divider()
            else:
                for idx, text in enumerate(results, start=1):
                    st.markdown(f"**{idx}.**")
                    st.write(text)
                    st.divider()

    def _render_analytics(self, documents):
        """Basic analytics of document library"""
        total_docs = len(documents)
        total_chunks = sum(doc.get("chunks", 0) for doc in documents)

        col1, col2 = st.columns(2)
        with col1:
            st.metric("Total Documents", total_docs)
        with col2:
            st.metric("Total Chunks", total_chunks)

        # Top documents by chunks
        if documents:
            st.subheader("Top Documents (by chunks)")
            top = sorted(documents, key=lambda d: d.get("chunks", 0), reverse=True)[:10]
            for doc in top:
                name = doc.get("name", "unknown")
                chunks = doc.get("chunks", 0)
                updated = (doc.get("last_updated") or "")[:19]
                st.write(f"- {name}: {chunks} chunks (updated {updated})")

    def _split_text(self, text: str, chunk_size: int, chunk_overlap: int):
        """Split plain text into overlapping chunks by words"""
        words = text.split()
        chunks = []
        step = max(1, chunk_size - chunk_overlap)
        for i in range(0, len(words), step):
            chunk_words = words[i:i + chunk_size]
            if not chunk_words:
                break
            chunks.append(" ".join(chunk_words))
            if i + chunk_size >= len(words):
                break
        return chunks
