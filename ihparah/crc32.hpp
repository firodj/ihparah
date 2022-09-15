//
//  crc32.hpp
//  ihparah
//
//  Created by Fadhil Mandaga on 15/09/22.
//

#ifndef crc32_hpp
#define crc32_hpp

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>


namespace base {

uint32_t Crc32(uint32_t sum, uint8_t* data, size_t size);
                                                
}

#endif /* crc32_hpp */
