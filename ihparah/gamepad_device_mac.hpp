//
//  gamepad_device_mac.h
//  ihparah
//
//  Created by Fadhil Mandaga on 15/09/22.
//

#ifndef gamepad_device_mac_h
#define gamepad_device_mac_h

#include <stddef.h>

#include <CoreFoundation/CoreFoundation.h>
#include <ForceFeedback/ForceFeedback.h>
#include <IOKit/hid/IOHIDManager.h>

namespace device {


enum class GamepadId : uint32_t {
  // ID value representing an unknown gamepad or non-gamepad.
  kUnknownGamepad = 0,
  
  kSonyProduct0268 = 0x054c0268,
  kSonyProduct05c4 = 0x054c05c4,
  kSonyProduct09cc = 0x054c09cc,
  kSonyProduct0ba0 = 0x054c0ba0,
  kSonyProduct0ce6 = 0x054c0ce6,
  kScufProduct7725 = 0x2e957725
};

enum GamepadBusType {
GAMEPAD_BUS_UNKNOWN,
GAMEPAD_BUS_USB,
GAMEPAD_BUS_BLUETOOTH
};

void Setup();
void Shutdown();
void Getar();
}

#endif /* gamepad_device_mac_h */
