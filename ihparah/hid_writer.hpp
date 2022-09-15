//
//  hid_writer.hpp
//  ihparah
//
//  Created by Fadhil Mandaga on 15/09/22.
//

#ifndef hid_writer_hpp
#define hid_writer_hpp


// Copyright 2019 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


#include <stddef.h>
#include <stdint.h>

#include <IOKit/hid/IOHIDManager.h>

#include <vector>

namespace device {

// HidWriter defines an interface for writing output reports to a single HID
// device.
class HidWriter {
 public:
  HidWriter() = default;
  virtual ~HidWriter() = default;

  // Platform implementation for writing an output report. |report| contains
  // the data to be written, with the report ID (if present) as the first byte.
  // Returns the number of bytes written, or zero on failure.
  virtual size_t WriteOutputReport(std::vector<uint8_t> &report) = 0;
};

class HidWriterMac final : public HidWriter {
 public:
  explicit HidWriterMac(IOHIDDeviceRef device_ref);
  ~HidWriterMac() override;

  // HidWriter implementation.
  size_t WriteOutputReport(std::vector<uint8_t> &report) override;

 private:
  IOHIDDeviceRef device_ref_;
};

}  // namespace device


#endif /* hid_writer_hpp */
