import streamlit as st
from typing import Optional
from datetime import datetime
import pandas as pd


class DocumentManager:
    """Enhanced document management UI for Streamlit"""
    
    def __init__(self, vector_db, pdf_processor):
        self.vector_db = vector_db
        self.pdf_processor = pdf_processor
    
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
            type=["pdf", "txt", "md"],
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
                
                if name.lower().endswith('.pdf'):
                    self.pdf_processor.chunk_size = chunk_size
                    self.pdf_processor.chunk_overlap = chunk_overlap
                    chunks = self.pdf_processor.process_pdf(uploaded_file)
                else:
                    content = uploaded_file.read().decode('utf-8', errors='ignore')
                    chunks = self._split_text(content, chunk_size, chunk_overlap)
                
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
                
                st
