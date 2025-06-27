#pragma once

#include <chrono>
#include <cstdint>
#include <thread>

inline void sleep(uint64_t ns) {
  std::this_thread::sleep_for(std::chrono::nanoseconds(ns));
}

inline void spin(uint64_t ns) {
  auto start = std::chrono::high_resolution_clock::now();

  while (true) {
    auto now = std::chrono::high_resolution_clock::now();

    auto elapsed = (now - start).count();

    if (elapsed >= static_cast<int64_t>(ns)) {
      break;
    }
  }
}
