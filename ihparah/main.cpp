//
//  main.cpp
//  ihparah
//
//  Created by Fadhil Mandaga on 14/09/22.
//

#include <iostream>
#include <chrono>
#include <thread>
#include "crc32.hpp"

#include "hid_writer.hpp"
#include "gamepad_device_mac.hpp"

using namespace std;

int main() {

    uint32_t crctest = ~base::Crc32(0xFFFFFFFF, (uint8_t*)"The quick brown fox jumps over the lazy dog", 43);
    std::cout <<  std::hex << crctest << std::endl;
    
    std::thread observer(device::Setup);
    
    std::cout << "hell o world!" << std::endl;
    
    
    std::this_thread::sleep_for(3000ms);
    device::Getar();
    std::this_thread::sleep_for(2000ms);
    
    device::Shutdown();
    
    observer.join();
    
    return 0;
}
