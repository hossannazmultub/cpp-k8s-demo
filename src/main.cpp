#include <iostream>
#include <thread>
#include <chrono>

int main() {
    std::cout << "==========================================" << std::endl;
    std::cout << " C++ Microservice Started Successfully!   " << std::endl;
    std::cout << "==========================================" << std::endl;

    unsigned int iteration = 0;
    while (true) {
        std::cout << "[Heartbeat #" << ++iteration << "] Service running normally..." << std::endl;
        std::this_thread::sleep_for(std::chrono::seconds(5));
    }

    return 0;
}