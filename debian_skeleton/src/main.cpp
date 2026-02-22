#include <iostream>
#include <string>
#include <csignal>
#include <atomic>
#include <thread>
#include <chrono>
#include <iomanip>
#include <map>
#include <regex>
#include <fstream>
#include <filesystem>

#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "core/SocketProbe.hpp"
#include "core/ebpf/BpfLoader.hpp"
#include "core/VisualMemory.hpp"
#include "modules/InitSecurityModule.hpp"
#include "modules/FilesystemModule.hpp"

namespace fs = std::filesystem;

std::atomic<bool> keepRunning{true};
rxcpp::composite_subscription engine_lifetime;

void clearScreen() { std::cout << "\033[2J\033[H"; }
void setGreen() { std::cout << "\033[1;32m"; }
void setRed() { std::cout << "\033[1;31m"; }
void resetColor() { std::cout << "\033[0m"; }

void signalHandler(int signum) {
    (void)signum;
    keepRunning = false;
    if (engine_lifetime.is_subscribed()) {
        engine_lifetime.unsubscribe();
    }
}

bool isValidMac(const std::string& mac) {
    const std::regex pattern("^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$");
    return std::regex_match(mac, pattern);
}

void secureSetupRouter(Venom::Core::BpfLoader& bpfLoader) {
    const std::string configPath = "/etc/venom";
    const std::string configFile = configPath + "/router.identity";

    if (!fs::exists(configPath)) {
        fs::create_directories(configPath);
        fs::permissions(configPath, fs::perms::owner_all, fs::perm_options::replace);
    }

    std::string mac_input;
    setGreen();
    std::cout << "\n[?] Kérem a Router MAC címét (XX:XX:XX:XX:XX:XX): ";
    resetColor();
    std::cin >> mac_input;

    if (!isValidMac(mac_input)) {
        setRed();
        std::cerr << "[!] BIZTONSÁGI RIASZTÁS: Érvénytelen MAC formátum!" << std::endl;
        resetColor();
        return;
    }

    try {
        std::ofstream ofs(configFile, std::ios::trunc);
        if (ofs.is_open()) {
            ofs << mac_input;
            ofs.close();
            fs::permissions(configFile, fs::perms::owner_read | fs::perms::owner_write, fs::perm_options::replace);
            std::cout << "[+] Router MAC rögzítve." << std::endl;
        }
    } catch (const std::exception& e) {
        std::cerr << "[!] Mentési hiba: " << e.what() << std::endl;
    }

    bpfLoader.setRouterMAC(mac_input);
}

std::string getHeartbeat(int tick, int rate) {
    (void)rate;
    std::string frame = "---";
    if (tick % 4 == 0) frame = "-^-";
    else if (tick % 4 == 1) frame = "/ \\";
    return frame;
}

int main(int argc, char* argv[]) {
    bool serviceMode = false;
    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--service") serviceMode = true;
    }

    std::signal(SIGINT, signalHandler);
    std::signal(SIGTERM, signalHandler);

    Venom::Core::Scheduler scheduler;
    Venom::Core::VenomBus bus;
    Venom::Core::BpfLoader bpfLoader;
    Venom::Core::VisualMemory vMem; 
    Venom::Modules::FilesystemModule fsModule(bus);
    Venom::Core::SocketProbe socketProbe(bus, 8888, Venom::Core::LogLevel::SECURITY_ONLY);

    try {
        { Venom::Modules::InitSecurityModule initMod; initMod.execute(); }
        secureSetupRouter(bpfLoader);
        
        // Csatlakozás a wlo1 interfészhez
        if (!bpfLoader.deploy("obj/core/ebpf/venom_shield.bpf.o", "wlo1")) {
            std::cerr << "[!] BPF Deployment sikertelen!" << std::endl;
        }

        scheduler.start(bus, bpfLoader, vMem);
        bus.startReactive(engine_lifetime, scheduler);

        if (serviceMode) {
            socketProbe.start();
            int frameCounter = 0;
            uint64_t last_filtered = 0;

            while (keepRunning && engine_lifetime.is_subscribed()) {
                auto snap = bus.getTelemetrySnapshot();
                auto bpfStats = bpfLoader.getStats();

                if (snap.null_routed > last_filtered) {
                    std::string bad_ip = bus.getLastFilteredIP();
                    if (!bad_ip.empty()) {
                        bpfLoader.blockIP(bad_ip);
                    }
                    last_filtered = snap.null_routed;
                }

                clearScreen();
                setGreen();
                std::cout << "#########################################################" << std::endl;
                std::cout << "#  WHITE VENOM v3.0 - CLI Dashboard [TRIXIE EDITION]    #" << std::endl;
                std::cout << "#########################################################" << std::endl;
                
                std::cout << "\n TOTAL FLUSHED BITS (Kernel Drop): ";
                setRed();
                std::cout << bpfStats.dropped_packets << " PKTS" << std::endl;
                setGreen();

                std::cout << "\n CORE TELEMETRY:" << std::endl;
                std::cout << " > Accepted: " << snap.accepted << std::endl;
                std::cout << " > Filtered (WC): " << snap.null_routed << std::endl;
                
                std::cout << "\n HEARTBEAT: [ " << getHeartbeat(frameCounter++, 0) << " ]" << std::endl;
                std::cout << "\n---------------------------------------------------------" << std::endl;
                std::cout << " eBPF Shield: " << (bpfLoader.isActive() ? "[ ACTIVE ON WLO1 ]" : "[ OFF ]") << std::endl;
                resetColor();

                std::this_thread::sleep_for(std::chrono::milliseconds(200));
            }

            socketProbe.stop();
            bpfLoader.detach();
        }
    } catch (const std::exception& e) {
        bpfLoader.detach();
    }
    scheduler.stop();
    return 0;
}
