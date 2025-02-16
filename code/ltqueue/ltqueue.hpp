#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <mpi.h>

template <typename T> class LTEnqueuer {
private:
  MPI_Comm _comm;
  MPI_Aint _size;
  MPI_Aint _dequeuer_rank;

  MPI_Win _data_win;
  T *_data_ptr;

  MPI_Win _first_win;
  MPI_Aint *_first_ptr;

  MPI_Win _last_win;
  MPI_Aint *_last_ptr;

  MPI_Win _announce_win;
  MPI_Aint *_announce_ptr;

  MPI_Win _free_later_win;
  MPI_Aint *_free_later_ptr;

  MPI_Win _help_win;
  T *_help_ptr;

public:
  LTEnqueuer(MPI_Comm comm, MPI_Aint dequeuer_rank, MPI_Aint size)
      : _comm{comm}, _size{size}, _dequeuer_rank{dequeuer_rank} {
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(size, sizeof(T), info, comm, &this->_data_ptr,
                     &this->_data_win);
    MPI_Win_allocate(1, sizeof(MPI_Aint), info, comm, &this->_first_ptr,
                     &this->_first_win);
    MPI_Win_allocate(1, sizeof(MPI_Aint), info, comm, &this->_last_ptr,
                     &this->_last_win);
    MPI_Win_allocate(1, sizeof(MPI_Aint), info, comm, &this->_announce_ptr,
                     &this->_announce_win);
    MPI_Win_allocate(1, sizeof(MPI_Aint), info, comm, &this->_free_later_ptr,
                     &this->_free_later_win);
    MPI_Win_allocate(1, sizeof(T), info, comm, &this->_help_ptr,
                     &this->_help_win);
  }
  LTEnqueuer(const LTEnqueuer &) = delete;
  LTEnqueuer &operator=(const LTEnqueuer &) = delete;
  ~LTEnqueuer() {
    MPI_Win_free(&this->_data_win);
    MPI_Win_free(&this->_first_win);
    MPI_Win_free(&this->_last_win);
    MPI_Win_free(&this->_announce_win);
    MPI_Win_free(&this->_free_later_win);
    MPI_Win_free(&this->_help_win);
  }

  bool enqueue(const T &data) {}
};

template <typename T> class LTDequeuer {
private:
  MPI_Comm _comm;
  MPI_Aint _size;
  MPI_Aint _rank;

  MPI_Win _data_win;
  T *_data_ptr;

  MPI_Win _first_win;
  MPI_Aint *_first_ptr;

  MPI_Win _last_win;
  MPI_Aint *_last_ptr;

  MPI_Win _announce_win;
  MPI_Aint *_announce_ptr;

  MPI_Win _free_later_win;
  MPI_Aint *_free_later_ptr;

  MPI_Win _help_win;
  T *_help_ptr;

public:
  LTDequeuer(MPI_Comm comm, MPI_Aint self_rank, MPI_Aint size)
      : _comm{comm}, _rank{self_rank}, _size{size} {
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(0, sizeof(T), info, comm,
                     &this->_data_ptr, &this->_data_win);
    MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm,
                     &this->_first_ptr, &this->_first_win);
    MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm,
                     &this->_last_ptr, &this->_last_win);
    MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm,
                     &this->_announce_ptr, &this->_announce_win);
    MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm,
                     &this->_free_later_ptr, &this->_free_later_win);
    MPI_Win_allocate(0, sizeof(T), info, comm, &this->_help_ptr,
                     &this->_help_win);
  }
  LTDequeuer(const LTDequeuer &) = delete;
  LTDequeuer &operator=(const LTDequeuer &) = delete;
  ~LTDequeuer() {
    MPI_Win_free(&this->_data_win);
    MPI_Win_free(&this->_first_win);
    MPI_Win_free(&this->_last_win);
    MPI_Win_free(&this->_announce_win);
    MPI_Win_free(&this->_free_later_win);
    MPI_Win_free(&this->_help_win);
  }
};
