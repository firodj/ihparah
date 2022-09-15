//
//  hid_writer.cpp
//  ihparah
//
//  Created by Fadhil Mandaga on 15/09/22.
//

#include "hid_writer.hpp"

#include <CoreFoundation/CoreFoundation.h>


namespace device {

HidWriterMac::HidWriterMac(IOHIDDeviceRef device_ref)
    : device_ref_(device_ref) {}

HidWriterMac::~HidWriterMac() = default;

size_t HidWriterMac::WriteOutputReport(std::vector<uint8_t> &report) {
  IOReturn success =
      IOHIDDeviceSetReport(device_ref_, kIOHIDReportTypeOutput, report[0],
                           report.data(), report.size());
  return (success == kIOReturnSuccess) ? report.size() : 0;
}

}  // namespace device

