#pragma once

#include <cstdint>
#include <mpi.h>

// put
template <typename T>
inline void write_sync(const T *src, int disp, unsigned int target_rank,
                       const MPI_Win &win) {
  MPI_Put(src, sizeof(T), MPI_CHAR, target_rank, disp, sizeof(T), MPI_CHAR,
          win);
  MPI_Win_flush(target_rank, win);
}

template <typename T>
inline void batch_write_sync(const T *src, int size, int disp,
                             unsigned int target_rank, const MPI_Win &win) {
  MPI_Put(src, sizeof(T) * size, MPI_CHAR, target_rank, disp, size * sizeof(T),
          MPI_CHAR, win);
  MPI_Win_flush(target_rank, win);
}

template <typename T>
inline void write_async(const T *src, int disp, unsigned int target_rank,
                        const MPI_Win &win) {
  MPI_Put(src, sizeof(T), MPI_CHAR, target_rank, disp, sizeof(T), MPI_CHAR,
          win);
}

template <typename T>
inline void batch_write_async(const T *src, int size, int disp,
                              unsigned int target_rank, const MPI_Win &win) {
  MPI_Put(src, sizeof(T) * size, MPI_CHAR, target_rank, disp, size * sizeof(T),
          MPI_CHAR, win);
  MPI_Win_flush(target_rank, win);
}

template <typename T>
inline void write_block(const T *src, int disp, unsigned int target_rank,
                        const MPI_Win &win) {
  MPI_Put(src, sizeof(T), MPI_CHAR, target_rank, disp, sizeof(T), MPI_CHAR,
          win);
  MPI_Win_flush_local(target_rank, win);
}

template <typename T>
inline void batch_write_block(const T *src, int size, int disp,
                              unsigned int target_rank, const MPI_Win &win) {
  MPI_Put(src, sizeof(T) * size, MPI_CHAR, target_rank, disp, size * sizeof(T),
          MPI_CHAR, win);
  MPI_Win_flush_local(target_rank, win);
}

// get
template <typename T>
inline void read_sync(T *dst, int disp, unsigned int target_rank,
                      const MPI_Win &win) {
  MPI_Get(dst, sizeof(T), MPI_CHAR, target_rank, disp, sizeof(T), MPI_CHAR,
          win);
  MPI_Win_flush(target_rank, win);
}

template <typename T>
inline void batch_read_sync(T *dst, int size, int disp,
                            unsigned int target_rank, const MPI_Win &win) {
  MPI_Get(dst, sizeof(T) * size, MPI_CHAR, target_rank, disp, size * sizeof(T),
          MPI_CHAR, win);
  MPI_Win_flush(target_rank, win);
}

template <typename T>
inline void read_async(T *dst, int disp, unsigned int target_rank,
                       const MPI_Win &win) {
  MPI_Get(dst, sizeof(T), MPI_CHAR, target_rank, disp, sizeof(T), MPI_CHAR,
          win);
}

template <typename T>
inline void batch_read_async(T *dst, int size, int disp,
                             unsigned int target_rank, const MPI_Win &win) {
  MPI_Get(dst, sizeof(T) * size, MPI_CHAR, target_rank, disp, size * sizeof(T),
          MPI_CHAR, win);
}

template <typename T>
inline void read_block(T *dst, int disp, unsigned int target_rank,
                       const MPI_Win &win) {
  MPI_Get(dst, sizeof(T), MPI_CHAR, target_rank, disp, sizeof(T), MPI_CHAR,
          win);
  MPI_Win_flush_local(target_rank, win);
}

template <typename T>
inline void batch_read_block(T *dst, int size, int disp,
                             unsigned int target_rank, const MPI_Win &win) {
  MPI_Get(dst, sizeof(T) * size, MPI_CHAR, target_rank, disp, size * sizeof(T),
          MPI_CHAR, win);
  MPI_Win_flush_local(target_rank, win);
}

// accumulate put

template <typename T>
inline void awrite_sync(const T *src, int disp, unsigned int target_rank,
                        const MPI_Win &win) {
  MPI_Accumulate(src, sizeof(T), MPI_CHAR, target_rank, disp, sizeof(T),
                 MPI_CHAR, MPI_REPLACE, win);
  MPI_Win_flush(target_rank, win);
}

template <typename T>
inline void batch_awrite_sync(const T *src, int size, int disp,
                              unsigned int target_rank, const MPI_Win &win) {
  MPI_Accumulate(src, sizeof(T) * size, MPI_CHAR, target_rank, disp,
                 sizeof(T) * size, MPI_CHAR, MPI_REPLACE, win);
  MPI_Win_flush(target_rank, win);
}

template <typename T>
inline void awrite_async(const T *src, int disp, unsigned int target_rank,
                         const MPI_Win &win) {
  MPI_Accumulate(src, sizeof(T), MPI_CHAR, target_rank, disp, sizeof(T),
                 MPI_CHAR, MPI_REPLACE, win);
}

template <typename T>
inline void batch_awrite_async(const T *src, int size, int disp,
                               unsigned int target_rank, const MPI_Win &win) {
  MPI_Accumulate(src, sizeof(T) * size, MPI_CHAR, target_rank, disp,
                 sizeof(T) * size, MPI_CHAR, MPI_REPLACE, win);
  MPI_Win_flush(target_rank, win);
}

template <typename T>
inline void awrite_block(const T *src, int disp, unsigned int target_rank,
                         const MPI_Win &win) {
  MPI_Accumulate(src, sizeof(T), MPI_CHAR, target_rank, disp, sizeof(T),
                 MPI_CHAR, MPI_REPLACE, win);
  MPI_Win_flush_local(target_rank, win);
}

template <typename T>
inline void batch_awrite_block(const T *src, int size, int disp,
                               unsigned int target_rank, const MPI_Win &win) {
  MPI_Accumulate(src, sizeof(T) * size, MPI_CHAR, target_rank, disp,
                 sizeof(T) * size, MPI_CHAR, MPI_REPLACE, win);
  MPI_Win_flush_local(target_rank, win);
}

// accumulate get
template <typename T>
inline void aread_sync(T *dst, int disp, unsigned int target_rank,
                       const MPI_Win &win) {
  MPI_Get_accumulate(NULL, 0, MPI_INT, dst, sizeof(T), MPI_CHAR, target_rank,
                     disp, sizeof(T), MPI_CHAR, MPI_NO_OP, win);
  MPI_Win_flush(target_rank, win);
}

template <typename T>
inline void batch_aread_sync(T *dst, int size, int disp,
                             unsigned int target_rank, const MPI_Win &win) {
  MPI_Get_accumulate(NULL, 0, MPI_INT, dst, sizeof(T) * size, MPI_CHAR,
                     target_rank, disp, size * sizeof(T), MPI_CHAR, MPI_NO_OP,
                     win);
  MPI_Win_flush(target_rank, win);
}

template <typename T>
inline void aread_async(T *dst, int disp, unsigned int target_rank,
                        const MPI_Win &win) {
  MPI_Get_accumulate(NULL, 0, MPI_INT, dst, sizeof(T), MPI_CHAR, target_rank,
                     disp, sizeof(T), MPI_CHAR, MPI_NO_OP, win);
  MPI_Get(dst, sizeof(T), MPI_CHAR, target_rank, disp, sizeof(T), MPI_CHAR,
          win);
}

template <typename T>
inline void batch_aread_async(T *dst, int size, int disp,
                              unsigned int target_rank, const MPI_Win &win) {
  MPI_Get_accumulate(NULL, 0, MPI_INT, dst, sizeof(T) * size, MPI_CHAR,
                     target_rank, disp, sizeof(T) * size, MPI_CHAR, MPI_NO_OP,
                     win);
}

template <typename T>
inline void aread_block(T *dst, int disp, unsigned int target_rank,
                        const MPI_Win &win) {
  MPI_Get_accumulate(NULL, 0, MPI_INT, dst, sizeof(T), MPI_CHAR, target_rank,
                     disp, sizeof(T), MPI_CHAR, MPI_NO_OP, win);
  MPI_Win_flush_local(target_rank, win);
}

template <typename T>
inline void batch_aread_block(T *dst, int size, int disp,
                              unsigned int target_rank, const MPI_Win &win) {
  MPI_Get_accumulate(NULL, 0, MPI_INT, dst, sizeof(T) * size, MPI_CHAR,
                     target_rank, disp, sizeof(T) * size, MPI_CHAR, MPI_NO_OP,
                     win);
  MPI_Win_flush_local(target_rank, win);
}

// fetch-and-get
template <typename T>
inline void fetch_and_add_sync(T *dst, uint64_t increment, int disp,
                               unsigned int target_rank, const MPI_Win &win) {
  if constexpr (sizeof(T) == 8) {
    uint64_t inc = increment;
    MPI_Fetch_and_op(&inc, dst, MPI_UINT64_T, target_rank, disp, MPI_SUM, win);
    MPI_Win_flush(target_rank, win);
  } else if constexpr (sizeof(T) == 4) {
    uint32_t inc = increment;
    MPI_Fetch_and_op(&inc, dst, MPI_UINT32_T, target_rank, disp, MPI_SUM, win);
    MPI_Win_flush(target_rank, win);
  } else if constexpr (sizeof(T) == 2) {
    uint16_t inc = increment;
    MPI_Fetch_and_op(&inc, dst, MPI_UINT16_T, target_rank, disp, MPI_SUM, win);
    MPI_Win_flush(target_rank, win);
  } else if constexpr (sizeof(T) == 1) {
    uint8_t inc = increment;
    MPI_Fetch_and_op(&inc, dst, MPI_UINT8_T, target_rank, disp, MPI_SUM, win);
    MPI_Win_flush(target_rank, win);
  } else {
    static_assert(false, "Invalid template type");
  }
}

// compare-and-swap
template <typename T>
inline void compare_and_swap_sync(const T *old_val, const T *new_val, T *result,
                                  int disp, unsigned int target_rank,
                                  const MPI_Win &win) {
  MPI_Datatype type;
  if constexpr (sizeof(T) == 8) {
    type = MPI_UINT64_T;
  } else if constexpr (sizeof(T) == 4) {
    type = MPI_UINT32_T;
  } else if constexpr (sizeof(T) == 2) {
    type = MPI_UINT16_T;
  } else if constexpr (sizeof(T) == 1) {
    type = MPI_UINT8_T;
  } else {
    static_assert(false, "Invalid template type");
  }

  MPI_Compare_and_swap(new_val, old_val, result, type, target_rank, disp, win);
  MPI_Win_flush(target_rank, win);
}
