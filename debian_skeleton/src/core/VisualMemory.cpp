#include "core/VisualMemory.hpp"

namespace Venom::Core {

VisualMemory::VisualMemory() : bit_array(BIT_SIZE) {
    for (size_t i = 0; i < BIT_SIZE; ++i) bit_array[i].store(false);
}

size_t VisualMemory::hash1(const std::string& key) const {
    size_t h = 0;
    for (char c : key) h = h * 31 + static_cast<unsigned char>(c);
    return h % BIT_SIZE;
}

size_t VisualMemory::hash2(const std::string& key) const {
    size_t h = 7;
    for (char c : key) h = h * 37 + static_cast<unsigned char>(c);
    return h % BIT_SIZE;
}

void VisualMemory::mark_as_wanted(const std::string& ip) {
    bit_array[hash1(ip)].store(true, std::memory_order_release);
    bit_array[hash2(ip)].store(true, std::memory_order_release);
    
    // Biztonságos számláló növelés
    std::lock_guard<std::mutex> lock(strike_mutex);
    strike_count[ip]++;
}

bool VisualMemory::is_on_wanted_list(const std::string& ip) const {
    if (!bit_array[hash1(ip)].load(std::memory_order_acquire)) return false;
    if (!bit_array[hash2(ip)].load(std::memory_order_acquire)) return false;
    return true;
}

int VisualMemory::get_strike_count(const std::string& ip) {
    std::lock_guard<std::mutex> lock(strike_mutex);
    if (strike_count.find(ip) == strike_count.end()) return 0;
    return strike_count[ip];
}

void VisualMemory::clear_memory() {
    for (size_t i = 0; i < BIT_SIZE; ++i) bit_array[i].store(false);
    std::lock_guard<std::mutex> lock(strike_mutex);
    strike_count.clear();
}

}
