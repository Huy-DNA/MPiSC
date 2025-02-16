#include <cstdio>
#include <cstdlib>
#include <mpi.h>

template <typename T> class LTEnqueuer {
private:
  MPI_Aint _dequeuer_rank;

  class Spsc {
    MPI_Aint _size;

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
    Spsc(MPI_Aint size, MPI_Comm comm) : _size{size} {
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
    ~Spsc() {
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
      MPI_Win_free(&this->_announce_win);
      MPI_Win_free(&this->_free_later_win);
      MPI_Win_free(&this->_help_win);
    }
  } _spsc;

public:
  LTEnqueuer(MPI_Comm comm, MPI_Aint dequeuer_rank, MPI_Aint size)
      : _dequeuer_rank{dequeuer_rank}, _spsc{size, comm} {}
  LTEnqueuer(const LTEnqueuer &) = delete;
  LTEnqueuer &operator=(const LTEnqueuer &) = delete;
  ~LTEnqueuer() {}
};

template <typename T> class LTDequeuer {
private:
  MPI_Aint _rank;

  class Spsc {
    MPI_Aint _size;

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
    Spsc(MPI_Aint size, MPI_Comm comm) : _size{size} {
      MPI_Info info;
      MPI_Info_create(&info);
      MPI_Info_set(info, "same_disp_unit", "true");

      MPI_Win_allocate(0, sizeof(T), info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_first_ptr,
                       &this->_first_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_last_ptr,
                       &this->_last_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_announce_ptr,
                       &this->_announce_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_free_later_ptr,
                       &this->_free_later_win);
      MPI_Win_allocate(0, sizeof(T), info, comm, &this->_help_ptr,
                       &this->_help_win);
    }

    ~Spsc() {
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
      MPI_Win_free(&this->_announce_win);
      MPI_Win_free(&this->_free_later_win);
      MPI_Win_free(&this->_help_win);
    }
  } _spsc;

public:
  LTDequeuer(MPI_Comm comm, MPI_Aint self_rank, MPI_Aint size)
      : _rank{self_rank}, _spsc{size, comm} {}
  LTDequeuer(const LTDequeuer &) = delete;
  LTDequeuer &operator=(const LTDequeuer &) = delete;
  ~LTDequeuer() {}
};
