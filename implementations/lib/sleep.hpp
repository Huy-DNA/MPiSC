#pragma once

#include <chrono>
#include <cstdint>
#include <thread>

inline void sleep(uint64_t us) {
  std::this_thread::sleep_for(std::chrono::microseconds(us));
}

inline void spin(uint64_t us) {
  auto start = std::chrono::high_resolution_clock::now();

  while (true) {
    auto now = std::chrono::high_resolution_clock::now();

    auto elapsed =
        std::chrono::duration_cast<std::chrono::microseconds>(now - start)
            .count();

    if (elapsed >= static_cast<int64_t>(us)) {
      break;
    }
  }
}
