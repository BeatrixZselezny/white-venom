#ifndef VISUAL_MEMORY_HPP
#define VISUAL_MEMORY_HPP

#include <vector>
#include <string>
#include <atomic>
#include <cstddef>
#include <map>
#include <mutex>
#include <functional> // Az callback-hez

namespace Venom::Core {

class VisualMemory {
private:
    static const size_t BIT_SIZE = 1024 * 1024;
    std::vector<std::atomic<bool>> bit_array;

    std::map<std::string, int> strike_count;
    std::mutex strike_mutex;

    // Callback függvény, hogy értesítsük a BpfLoadert az új tiltásról
    std::function<void(uint32_t)> on_kernel_block_request;

    size_t hash1(const std::string& key) const;
    size_t hash2(const std::string& key) const;

public:
    VisualMemory();
    ~VisualMemory() = default;

    void mark_as_wanted(const std::string& ip);
    bool is_on_wanted_list(const std::string& ip) const;
    
    int get_strike_count(const std::string& ip);
    void clear_memory();

    // Ezzel drótozzuk össze a BpfLoader-rel
    void set_blocking_callback(std::function<void(uint32_t)> cb) {
        on_kernel_block_request = cb;
    }
};

} // namespace Venom::Core

#endif
