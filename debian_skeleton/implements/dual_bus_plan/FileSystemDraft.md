```cpp
// ... a private rész folytatása ...

    private:
        std::vector<FilesystemPathPolicy> policies;
        
        // --- REACTIVE KERNEL HOOKS (A B Opcióhoz) ---
        int inotify_fd;      // A "fül", amivel hallgatózunk
        int epoll_fd;        // A non-blocking eseményhurok vezérlője
        
        // Mapping: Watch Descriptor (int) -> Útvonal (string)
        // Hogy tudjuk, melyik fájl szólt vissza
        std::map<int, std::string> watch_registry; 

        void auditPath(const FilesystemPathPolicy& policy);
        
        // Helper a setup-hoz
        void setupWatches();
        void handleEvents(); // Ez olvassa majd ki az eseményeket
```