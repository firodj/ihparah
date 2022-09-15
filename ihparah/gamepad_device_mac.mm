//
//  gamepad_device_mac.m
//  ihparah
//
//  Created by Fadhil Mandaga on 15/09/22.
//

#include "gamepad_device_mac.hpp"

#import <Foundation/Foundation.h>
#include <IOKit/hid/IOHIDKeys.h>

#include <vector>
#include <string>
#include <iostream>
#include <array>
#include "hid_writer.hpp"
#include "crc32.hpp"

namespace device {

    // Expected values for |version_number| when connected over USB and Bluetooth.
    const uint16_t kDualshock4VersionUsb = 0x0100;
    const uint16_t kDualshock4VersionBluetooth = 0;

    // Report IDs.
    const uint8_t kReportId05 = 0x05;
    const uint8_t kReportId11 = 0x11;

    // Maximum in-range values for HID report fields.
    const uint8_t kRumbleMagnitudeMax = 0xff;
    const float kAxisMax = 255.0f;
    const float kDpadMax = 7.0f;
    
namespace {
// http://www.usb.org/developers/hidpage
const uint16_t kGenericDesktopUsagePage = 0x01;
const uint16_t kGameControlsUsagePage = 0x05;
const uint16_t kButtonUsagePage = 0x09;
const uint16_t kConsumerUsagePage = 0x0c;

const uint16_t kJoystickUsageNumber = 0x04;
const uint16_t kGameUsageNumber = 0x05;
const uint16_t kMultiAxisUsageNumber = 0x08;
const uint16_t kAxisMinimumUsageNumber = 0x30;
const uint16_t kSystemMainMenuUsageNumber = 0x85;
const uint16_t kPowerUsageNumber = 0x30;
const uint16_t kSearchUsageNumber = 0x0221;
const uint16_t kHomeUsageNumber = 0x0223;
const uint16_t kBackUsageNumber = 0x0224;
const uint16_t kRecordUsageNumber = 0xb2;


struct SpecialUsages {
  const uint16_t usage_page;
  const uint16_t usage;
} kSpecialUsages[] = {
    // Xbox One S pre-FW update reports Xbox button as SystemMainMenu over BT.
    {kGenericDesktopUsagePage, kSystemMainMenuUsageNumber},
    // Power is used for the Guide button on the Nvidia Shield 2015 gamepad.
    {kConsumerUsagePage, kPowerUsageNumber},
    // Search is used for the Guide button on the Nvidia Shield 2017 gamepad.
    {kConsumerUsagePage, kSearchUsageNumber},
    // Start, Back, and Guide buttons are often reported as Consumer Home or
    // Back.
    {kConsumerUsagePage, kHomeUsageNumber},
    {kConsumerUsagePage, kBackUsageNumber},
    {kConsumerUsagePage, kRecordUsageNumber},
};
    
const size_t kSpecialUsagesLen = std::size(kSpecialUsages);

float NormalizeAxis(CFIndex value, CFIndex min, CFIndex max) {
  return (2.f * (value - min) / static_cast<float>(max - min)) - 1.f;
}

float NormalizeUInt8Axis(uint8_t value, uint8_t min, uint8_t max) {
  return (2.f * (value - min) / static_cast<float>(max - min)) - 1.f;
}

float NormalizeUInt16Axis(uint16_t value, uint16_t min, uint16_t max) {
  return (2.f * (value - min) / static_cast<float>(max - min)) - 1.f;
}

float NormalizeUInt32Axis(uint32_t value, uint32_t min, uint32_t max) {
  return (2.f * (value - min) / static_cast<float>(max - min)) - 1.f;
}

GamepadBusType QueryBusType(IOHIDDeviceRef device) {
  
    NSString* transport = (__bridge NSString*)      IOHIDDeviceGetProperty(device, CFSTR(kIOHIDTransportKey));
    
  if (transport) {
      std::string transport_name([transport UTF8String]);

    if (transport_name == kIOHIDTransportUSBValue)
      return GAMEPAD_BUS_USB;
    if (transport_name == kIOHIDTransportBluetoothValue ||
        transport_name == kIOHIDTransportBluetoothLowEnergyValue) {
      return GAMEPAD_BUS_BLUETOOTH;
    }
  }
  return GAMEPAD_BUS_UNKNOWN;
}

#pragma pack(push, 1)
struct ControllerData {
  uint8_t axis_left_x;
  uint8_t axis_left_y;
  uint8_t axis_right_x;
  uint8_t axis_right_y;
  uint8_t axis_dpad : 4;
  bool button_square : 1;
  bool button_cross : 1;
  bool button_circle : 1;
  bool button_triangle : 1;
  bool button_left_1 : 1;
  bool button_right_1 : 1;
  bool button_left_2 : 1;
  bool button_right_2 : 1;
  bool button_share : 1;
  bool button_options : 1;
  bool button_left_3 : 1;
  bool button_right_3 : 1;
  bool button_ps : 1;
  bool button_touch : 1;
  uint8_t sequence_number : 6;
  uint8_t axis_left_2;
  uint8_t axis_right_2;
  uint16_t timestamp;
  uint8_t sensor_temperature;
  uint16_t axis_gyro_pitch;
  uint16_t axis_gyro_yaw;
  uint16_t axis_gyro_roll;
  uint16_t axis_accelerometer_x;
  uint16_t axis_accelerometer_y;
  uint16_t axis_accelerometer_z;
  uint8_t padding1[5];
  uint8_t battery_info : 5;
  uint8_t padding2 : 2;
  bool extension_detection : 1;
};
#pragma pack(pop)
static_assert(sizeof(ControllerData) == 30,
              "ControllerData has incorrect size");

#pragma pack(push, 1)
struct TouchPadData {
  uint8_t touch_data_timestamp;
  uint8_t touch0_id : 7;
  bool touch0_is_invalid : 1;
  uint8_t touch0_data[3];
  uint8_t touch1_id : 7;
  bool touch1_is_invalid : 1;
  uint8_t touch1_data[3];
};
#pragma pack(pop)
static_assert(sizeof(TouchPadData) == 9, "TouchPadData has incorrect size");

#pragma pack(push, 1)
struct Dualshock4InputReport11 {
  uint8_t padding1[2];
  ControllerData controller_data;
  uint8_t padding2[2];
  uint8_t touches_count;
  TouchPadData touches[4];
  uint8_t padding3[2];
  uint32_t crc32;
};
#pragma pack(pop)
static_assert(sizeof(Dualshock4InputReport11) == 77,
              "Dualshock4InputReport11 has incorrect size");

    void  DumpHex(std::vector<uint8_t> data) {
        for (int i = 0; i < data.size(); i += 16) {
            
            
            std::printf("0x%04X | ", i);
            for (int j = i;  j < i+16; j++) {
                if (j < data.size())
                    std::printf("%02X ", data[j]);
                else
                    std::printf("   ");
            }
            std::printf(" | ");
            
            for (int j = i;  j < i+16; j++) {
                if (j < data.size())
                    if (data[j] >= 0x20 && data[j] < 0x7F) {
                        std::printf("%c", data[j]);
                    } else {
                        std::printf(".");
                    }
                else
                    std::printf(" ");
            }
            
            std::printf("\n");
        }
    }

class Dualshock4Controller final {

public:
  Dualshock4Controller(GamepadId gamepad_id,
                       GamepadBusType bus_type,
                       std::unique_ptr<HidWriter> writer): gamepad_id_(gamepad_id),
    bus_type_(bus_type),
    writer_(std::move(writer)) {
        
    }
    
    ~Dualshock4Controller() {
        // do nothing
    }

    static bool IsDualshock4(GamepadId gamepad_id) {
      return gamepad_id == GamepadId::kSonyProduct05c4 ||
             gamepad_id == GamepadId::kSonyProduct09cc ||
             gamepad_id == GamepadId::kScufProduct7725;
    }
    
    void SetVibration(double strong_magnitude,
                      double weak_magnitude) {
      // Genuine DualShock 4 gamepads use an alternate output report when connected
      // over Bluetooth. Always send USB-mode reports to SCUF Vantage gamepads.
      if (bus_type_ == GAMEPAD_BUS_BLUETOOTH &&
          gamepad_id_ != GamepadId::kScufProduct7725) {
        SetVibrationBluetooth(strong_magnitude, weak_magnitude);
        return;
      }

      SetVibrationUsb(strong_magnitude, weak_magnitude);
    }
    
    void SetVibrationUsb(double strong_magnitude,
                                               double weak_magnitude) {
    
      // Construct a USB output report with report ID 0x05. In USB mode, the 0x05
      // report is used to control vibration, LEDs, and audio volume.
      // https://github.com/torvalds/linux/blob/master/drivers/hid/hid-sony.c#L2105
        std::vector<uint8_t> control_report(32);
        std::fill(control_report.begin(), control_report.end(), 0);
      control_report[0] = kReportId05;
      control_report[1] = 0x01;  // motor only, don't update LEDs
      control_report[4] = (weak_magnitude * kRumbleMagnitudeMax);
      control_report[5] = (strong_magnitude * kRumbleMagnitudeMax);

      size_t success = writer_->WriteOutputReport(control_report);
        std::cout << "write output (usb): " << success << std::endl;
    }

    void SetVibrationBluetooth(double strong_magnitude,
                                                     double weak_magnitude) {
     
      // Construct a Bluetooth output report with report ID 0x11. In Bluetooth mode,
      // the 0x11 report is used to control vibration, LEDs, and audio volume.
      // https://www.psdevwiki.com/ps4/DS4-BT#0x11_2
      std::vector<uint8_t> control_report(78);
        std::fill(control_report.begin(), control_report.end(), 0);
      control_report[0] = kReportId11;
      control_report[1] = 0xc0;  // unknown
      control_report[2] = 0x20;  // unknown
      control_report[3] = 0xf1;  // motor only, don't update LEDs
      control_report[4] = 0x04;  // unknown
      control_report[6] = (weak_magnitude * kRumbleMagnitudeMax);
      control_report[7] = (strong_magnitude * kRumbleMagnitudeMax);
      control_report[21] = 0x43;  // volume left
      control_report[22] = 0x43;  // volume right
      control_report[24] = 0x4d;  // volume speaker
      control_report[25] = 0x85;  // unknown

      // The last four bytes of the report hold a CRC32 checksum. Compute the
      // checksum and store it in little-endian byte order.
        uint32_t crc = ComputeDualshock4Checksum(control_report.data(), control_report.size() - 4);
         
      control_report[control_report.size() - 4] = crc & 0xff;
      control_report[control_report.size() - 3] = (crc >> 8) & 0xff;
      control_report[control_report.size() - 2] = (crc >> 16) & 0xff;
      control_report[control_report.size() - 1] = (crc >> 24) & 0xff;
        
        DumpHex(control_report);

        size_t success = writer_->WriteOutputReport(control_report);
        std::cout << "write output (bt): " << std::dec  << success << std::endl;
    }
    

    uint32_t ComputeDualshock4Checksum(uint8_t *report_data, size_t size) {
      // The Bluetooth report checksum includes a constant header byte not contained
      // in the report data.
      uint8_t bt_header = 0xa2;
        uint32_t crc = base::Crc32(0xffffffff, &bt_header, 1);
      // Extend the checksum with the contents of the report.
        return ~base::Crc32(crc, report_data, size);
    }

    bool ProcessInputReport(uint8_t report_id,
                                                  std::vector<uint8_t> &report) {
      // Input report 0x11 is the full-feature mode input report. It includes
      // gamepad button and axis state, touch inputs, motion inputs, battery level
      // and temperature. Dualshock4 starts sending this report after it has
      // received an output report with ID 0x11. Prior to receiving the output
      // report, input report 0x01 is sent which includes button and axis state.
      //
      // Here we only handle the full-feature report. Input report 0x01 is handled
      // by the platform's HID data fetcher.
      if (report_id != kReportId11 ||
          report.size() < sizeof(Dualshock4InputReport11)) {
        return false;
      }

      const auto* data =
          reinterpret_cast<const Dualshock4InputReport11*>(report.data());
        
        if (data->controller_data.button_square) {
            std::cout << "[] " << std::endl;
        }
        if (data->controller_data.button_cross) {
            std::cout << "X " << std::endl;
        }
        if (data->controller_data.button_circle) {
            std::cout << "O " << std::endl;
        }
        if (data->controller_data.button_triangle) {
            std::cout << "/\ " << std::endl;
        }
        
                return true;
    }
    
    GamepadId gamepad_id_;
    GamepadBusType bus_type_;
    std::unique_ptr<HidWriter> writer_;
};

   
    
Dualshock4Controller  *ds4 = NULL;

    NSDictionary* DeviceMatching(uint32_t usage_page, uint32_t usage) {
      return @{
          (__bridge NSString *)CFSTR(kIOHIDDeviceUsagePageKey) : @(usage_page),
          (__bridge NSString *)CFSTR(kIOHIDDeviceUsageKey) : @(usage)
      };
    }
    
}

    void DeviceAddCallback(void* context,
                                                          IOReturn result,
                                                          void* sender,
                                                          IOHIDDeviceRef device) {
        
        NSNumber* location_id = (__bridge NSNumber*)
              IOHIDDeviceGetProperty(device, CFSTR(kIOHIDLocationIDKey));
        
        NSNumber* vendor_id = (__bridge NSNumber*)
              IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
        NSNumber* product_id = (__bridge NSNumber*)
              IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
      NSNumber* version_number = (__bridge NSNumber*)
          IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVersionNumberKey));
      NSString* product = (__bridge NSString*)          IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
     
      std::string product_name([product UTF8String]);
        
        int location_int = [location_id intValue];
        uint16_t vendor_int = [vendor_id intValue];
        uint16_t product_int = [product_id intValue];
        uint16_t version_int = [version_number intValue];
        
        std::cout << "device add callback; location_id=" << location_id <<
        " vendor: " <<std::hex  << vendor_int <<
        " product: " << product_int <<
        " version: " << version_int<<
        " name: " << product_name << std::endl;
        
        GamepadId gamepad_id =static_cast<GamepadId>((vendor_int << 16) | product_int);
        
        if (Dualshock4Controller::IsDualshock4(gamepad_id)) {
            ds4 = new Dualshock4Controller(gamepad_id, QueryBusType(device),  std::make_unique<HidWriterMac>(device));
            std::cout << "dual shock 4 ni ye!" << std::endl;
        }
        
    }

    void DeviceRemoveCallback(void* context,
                                                             IOReturn result,
                                                             void* sender,
                                                             IOHIDDeviceRef ref) {
        std::cout << "device remove callback:" << std::endl;
      
    }

    void ValueChangedCallback(void* context,
                                                             IOReturn result,
                                                             void* sender,
                                                             IOHIDValueRef value) {
        IOHIDElementRef element = IOHIDValueGetElement(value);
        IOHIDDeviceRef device = IOHIDElementGetDevice(element);
        
        uint32_t value_length = IOHIDValueGetLength(value);
        
        uint32_t report_id = IOHIDElementGetReportID(element);
        
        std::vector<uint8_t> report(value_length);
        std::memcpy(report.data(), IOHIDValueGetBytePtr(value), value_length);
        
        auto eletype = IOHIDElementGetType(element);
        switch (eletype) {
            case kIOHIDElementTypeInput_Misc:
                //std::cout << "misc." << std::endl;
                break;
            case     kIOHIDElementTypeInput_Button:
                std::cout << "button." << std::endl;
                ds4->SetVibration(0.5, 0.5);
                break;
            case     kIOHIDElementTypeInput_Axis:
                std::cout << "axis." << std::endl; break;
            case     kIOHIDElementTypeInput_ScanCodes:
                std::cout << "scancodes." << std::endl; break;
            case     kIOHIDElementTypeInput_NULL:
                std::cout << "null." << std::endl; break;
            case    kIOHIDElementTypeOutput:
                std::cout << "output." << std::endl; break;
            case     kIOHIDElementTypeFeature:
                std::cout << "feature." << std::endl; break;
            case     kIOHIDElementTypeCollection:
                std::cout << "collection." << std::endl; break;
            default:
                std::cout << "unknown." << eletype << std::endl; break;
            
        }
        if (ds4) {
            bool success = ds4->ProcessInputReport(report_id, report);
            //std::cout << "process input success: " << success << std::endl;
        }
    }

    IOHIDManagerRef hid_manager_ref = NULL;
    CFRunLoopRef run_loop_ref = NULL;
    
    void Setup() {
        run_loop_ref = CFRunLoopGetCurrent();
        hid_manager_ref =         IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
        
        if (!hid_manager_ref) {
            return;
        }
        
        
        NSArray *criteria =
              [[NSArray alloc] initWithObjects:DeviceMatching(kGenericDesktopUsagePage,
                                                              kJoystickUsageNumber),
                                               DeviceMatching(kGenericDesktopUsagePage,
                                                              kGameUsageNumber),
                                               DeviceMatching(kGenericDesktopUsagePage,
                                                              kMultiAxisUsageNumber),
                                               nil];
    
        
        ::IOHIDManagerSetDeviceMatchingMultiple(hid_manager_ref,
                                                (__bridge CFArrayRef)criteria);
        
        
        
        // Register for plug/unplug notifications.
          IOHIDManagerRegisterDeviceMatchingCallback(hid_manager_ref,
                                                     DeviceAddCallback, NULL);
          IOHIDManagerRegisterDeviceRemovalCallback(hid_manager_ref,
                                                    DeviceRemoveCallback, NULL);

          // Register for value change notifications.
          IOHIDManagerRegisterInputValueCallback(hid_manager_ref, ValueChangedCallback,
                                                 NULL);

          IOHIDManagerScheduleWithRunLoop(hid_manager_ref, run_loop_ref,
                                          kCFRunLoopDefaultMode);

          const auto result = IOHIDManagerOpen(hid_manager_ref, kIOHIDOptionsTypeNone);
          bool success = (result == kIOReturnSuccess || result == kIOReturnExclusiveAccess);
        
        
        std::cout << "success: " << success << std::endl;
        
        CFRunLoopRun();
    }
    
    void Shutdown() {
        if (ds4)  {
            ds4->SetVibration(0, 0);
            delete ds4;
        }
        
        IOHIDManagerUnscheduleFromRunLoop(hid_manager_ref, run_loop_ref,
                                            kCFRunLoopDefaultMode);
        IOHIDManagerClose(hid_manager_ref, kIOHIDOptionsTypeNone);
        
        CFRunLoopStop(run_loop_ref);
    }
    
    void Getar() {
        if (ds4) {
            ds4->SetVibration(0.7, 0.7);
        }
    }
}
