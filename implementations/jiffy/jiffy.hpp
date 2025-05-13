#pragma once

#include "../lib/bclx/bclx/bclx/bclx.hpp"
#include <cstdio>
#include <cstdlib>
#include <mpi.h>

template <typename T> class JiffyEnqueuer {
private:
public:
  JiffyEnqueuer() {}

  JiffyEnqueuer(const JiffyEnqueuer &) = delete;
  JiffyEnqueuer &operator=(const JiffyEnqueuer &) = delete;

  ~JiffyEnqueuer() {}
};

template <typename T> class JiffyDequeuer {
private:
public:
  JiffyDequeuer() {}

  JiffyDequeuer(const JiffyDequeuer &) = delete;
  JiffyDequeuer &operator=(const JiffyDequeuer &) = delete;
  ~JiffyDequeuer() {}
};
