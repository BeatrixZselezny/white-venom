#ifndef VISUAL_MEMORY_HPP
#define VISUAL_MEMORY_HPP

#include <vector>
#include <string>
#include <atomic>
#include <cstddef>
#include <map>
#include <mutex>

namespace Venom::Core {

class VisualMemory {
private:
    static const size_t BIT_SIZE = 1024 * 1024; 
    std::vector<std::atomic<bool>> bit_array;

    // Hiányzó tagok pótolva a fordításhoz
    std::map<std::string, int> strike_count;
    std::mutex strike_mutex;

    size_t hash1(const std::string& key) const;
    size_t hash2(const std::string& key) const;

public:
    VisualMemory();
    ~VisualMemory() = default;

    void mark_as_wanted(const std::string& ip);
    bool is_on_wanted_list(const std::string& ip) const;
    
    // Lekérdezés a büntetés-szinthez
    int get_strike_count(const std::string& ip);

    void clear_memory();
};

} // namespace Venom::Core

#endif
