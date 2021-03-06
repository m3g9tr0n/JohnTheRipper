/*
 * Developed by Claudio André <claudio.andre at correios.net.br> in 2012
 *
 * More information at http://openwall.info/wiki/john/OpenCL-RAWSHA-512
 * More information at http://openwall.info/wiki/john/OpenCL-XSHA-512
 *
 * Copyright (c) 2012 Claudio André <claudio.andre at correios.net.br>
 * This program comes with ABSOLUTELY NO WARRANTY; express or implied.
 *
 * This is free software, and you are welcome to redistribute it
 * under certain conditions; as expressed here
 * http://www.gnu.org/licenses/gpl-2.0.html
 */

#include "opencl_rawsha512.h"

inline void _memcpy(               uint32_t * dest,
                    __global const uint32_t * src,
                             const uint32_t   len) {

    for (uint32_t i = 0; i < len; i += 4)
        *dest++ = *src++;
}

inline uint32_t sha512_block(sha512_ctx * ctx) {
    uint64_t a = H0;
    uint64_t b = H1;
    uint64_t c = H2;
    uint64_t d = H3;
    uint64_t e = H4;
    uint64_t f = H5;
    uint64_t g = H6;
    uint64_t h = H7;
    uint64_t t;
    uint64_t w[16];	//#define  w   ctx->buffer->mem_64

    #pragma unroll
    for (int i = 0; i < 15; i++)
        w[i] = SWAP64(ctx->buffer[i].mem_64[0]);
    w[15] = (uint64_t) (ctx->buflen * 8);

    /* Do the job, up to 77 iterations. */
    SHA512_SHORT()

    /* Return partial hash value. */
    return d;
}

__kernel
void kernel_crypt_raw(__global   const uint32_t  * keys_buffer,
                      __global   const uint32_t  * index,
                      __global   uint32_t        * out_buffer) {

    //Compute buffers (on CPU and NVIDIA, better private)
    sha512_ctx     ctx;

    //Get the task to be done
    size_t gid = get_global_id(0);

    //Get position and length of informed key.
    uint32_t base = index[gid];
    ctx.buflen = base & 63;

    //Ajust keys to it start position.
    keys_buffer += (base >> 6);

    //Clear the buffer.
    CLEAR_CTX_64(0) \
    CLEAR_CTX_64(1) \
    CLEAR_CTX_64(2) \
    CLEAR_CTX_64(3) \
    CLEAR_CTX_64(4) \
    CLEAR_CTX_64(5) \
    CLEAR_CTX_64(6) \
    CLEAR_CTX_64(7) \
    CLEAR_CTX_64(8) \
    CLEAR_CTX_64(9) \
    CLEAR_CTX_64(10) \
    CLEAR_CTX_64(11) \
    CLEAR_CTX_64(12) \
    CLEAR_CTX_64(13) \
    CLEAR_CTX_64(14)

    //Get password.
    _memcpy(ctx.buffer->mem_32, keys_buffer, ctx.buflen);

    //Prepare buffer.
    PUT(F_BUFFER, ctx.buflen, 0x80);
    CLEAR_BUFFER_64_FAST(ctx.buffer->mem_64, ctx.buflen + 1);

    /* Run the collected hash value through SHA512. Return parcial results */
    out_buffer[gid] = sha512_block(&ctx);
}

__kernel
void kernel_crypt_xsha(__constant sha512_salt     * salt,
                       __global   const uint32_t  * keys_buffer,
                       __global   const uint32_t  * index,
                       __global   uint32_t        * out_buffer) {

    //Compute buffers (on CPU and NVIDIA, better private)
    sha512_ctx     ctx;

    //Get the task to be done
    size_t gid = get_global_id(0);

    //Get position and length of informed key.
    uint32_t base = index[gid];
    ctx.buflen = base & 63;

    //Ajust keys to it start position.
    keys_buffer += (base >> 6);

    //Clear the buffer.
    CLEAR_CTX_64(0) \
    CLEAR_CTX_64(1) \
    CLEAR_CTX_64(2) \
    CLEAR_CTX_64(3) \
    CLEAR_CTX_64(4) \
    CLEAR_CTX_64(5) \
    CLEAR_CTX_64(6) \
    CLEAR_CTX_64(7) \
    CLEAR_CTX_64(8) \
    CLEAR_CTX_64(9) \
    CLEAR_CTX_64(10) \
    CLEAR_CTX_64(11) \
    CLEAR_CTX_64(12) \
    CLEAR_CTX_64(13) \
    CLEAR_CTX_64(14)

    //Get salt information.
    ctx.buffer->mem_32[0] = salt->salt;

    //Get password.
    _memcpy(ctx.buffer->mem_32 + 1, keys_buffer, ctx.buflen);
    ctx.buflen += SALT_SIZE_X;

    //Prepare buffer.
    PUT(F_BUFFER, ctx.buflen, 0x80);
    CLEAR_BUFFER_64_FAST(ctx.buffer->mem_64, ctx.buflen + 1);

    /* Run the collected hash value through SHA512. Return parcial results */
    out_buffer[gid] = sha512_block(&ctx);
}

__kernel
void kernel_cmp(__global   uint32_t        * partial_hash,
                __constant uint32_t        * partial_binary,
                __global   int             * result) {

    //Get the task to be done
    size_t gid = get_global_id(0);

    //Compare with partial computed hash.
    if (*partial_binary == partial_hash[gid]) {
        //Barrier point. FIX IT
        *result = 1;
    }
}
