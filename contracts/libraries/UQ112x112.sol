// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))


/** Q stands for "fixed-point number format", it is a way of representing real numbers in binary
    using a fixed number of bits for the integer and fractional parts. 
    In this library, the format used is UQ112x112, which means that the number is represented 
    using 112 bits for the integer part and 112 bits for the fractional part. 
    
    The range of representable numbers is [0, 2**112 - 1] and the resolution 
    (smallest possible difference between two representable numbers) is 1 / 2**112.
 */

library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112
    /**
      encode(uint112 y) takes an unsigned integer y (which should be less than 2**112) and 
      returns a UQ112x112 fixed-point number. It does this by multiplying y by 2**112 (which 
      is a constant defined as Q112) and returning the result as an unsigned integer with 224 
      bits (which is enough to hold the product without overflow).
     */
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    /**
     * 
     * @param x  uint224 x, @param y uint112 y) takes two unsigned integers x and y and returns the result of 
     * dividing x by y. This operation is only valid if y is not zero. Since x represents a fixed-point number 
     * in UQ112x112 format, the result of the division is also a fixed-point number in UQ112x112 format. 
     * The result "z" is returned as an unsigned integer with 224 bits.
     */
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}