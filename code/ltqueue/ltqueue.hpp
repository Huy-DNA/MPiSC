#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>

template <typename T> class LTEnqueuer {
private:
  constexpr static MPI_Aint NULL_INDEX = ~((MPI_Aint)0);

  MPI_Datatype _mpi_type;
  MPI_Aint _self_rank;
  MPI_Aint _dequeuer_rank;

  MPI_Win _counter_win;
  MPI_Aint *_counter_ptr;

  struct data_t {
    T data;
    std::uint64_t timestamp;
  };

  class Spsc {
    MPI_Datatype _mpi_type;
    MPI_Aint _self_rank;
    MPI_Aint _dequeuer_rank;

    MPI_Aint _size;

    MPI_Win _data_win;
    data_t *_data_ptr;

    MPI_Win _first_win;
    MPI_Aint *_first_ptr;

    MPI_Win _last_win;
    MPI_Aint *_last_ptr;

    MPI_Win _announce_win;
    MPI_Aint *_announce_ptr;

    MPI_Win _free_later_win;
    MPI_Aint *_free_later_ptr;

    MPI_Win _help_win;
    data_t *_help_ptr;

  public:
    Spsc(MPI_Comm comm, MPI_Datatype original_type, MPI_Aint size,
         MPI_Aint self_rank, MPI_Aint dequeuer_rank)
        : _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank}, _size{size} {
      int blocklengths[] = {1, 1};
      MPI_Datatype types[] = {original_type, MPI_UINT64_T};
      MPI_Aint offsets[2];
      offsets[0] = offsetof(data_t, data);
      offsets[1] = offsetof(data_t, timestamp);
      MPI_Type_create_struct(2, blocklengths, offsets, types, &this->_mpi_type);
      MPI_Type_commit(&this->_mpi_type);

      MPI_Info info;
      MPI_Info_create(&info);
      MPI_Info_set(info, "same_disp_unit", "true");

      MPI_Win_allocate(size * sizeof(data_t), sizeof(data_t), info, comm,
                       &this->_data_ptr, &this->_data_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_first_ptr, &this->_first_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_last_ptr, &this->_last_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_announce_ptr, &this->_announce_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_free_later_ptr, &this->_free_later_win);
      MPI_Win_allocate(sizeof(data_t), sizeof(data_t), info, comm,
                       &this->_help_ptr, &this->_help_win);

      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_announce_win);
      MPI_Win_lock_all(0, this->_free_later_win);
      *this->_first_ptr = 0;
      *this->_last_ptr = 0;
      *this->_announce_ptr = NULL_INDEX;
      *this->_free_later_ptr = NULL_INDEX;
      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_announce_win);
      MPI_Win_unlock_all(this->_free_later_win);
      MPI_Barrier(comm);
    }
    ~Spsc() {
      MPI_Type_free(&this->_mpi_type);
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
      MPI_Win_free(&this->_announce_win);
      MPI_Win_free(&this->_free_later_win);
      MPI_Win_free(&this->_help_win);
    }

    bool enqueue(const data_t &data) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_announce_win);
      MPI_Win_lock_all(0, this->_free_later_win);
      MPI_Win_lock_all(0, this->_data_win);

      MPI_Aint first;
      MPI_Aint last;
      MPI_Aint announce;
      MPI_Aint free_later;
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &first, 1, MPI_AINT,
                         this->_self_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_first_win);
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &last, 1, MPI_AINT,
                         this->_self_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_last_win);
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &announce, 1, MPI_AINT,
                         this->_self_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_announce_win);
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &free_later, 1, MPI_AINT,
                         this->_self_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_free_later_win);
      MPI_Win_flush(this->_self_rank, this->_first_win);
      MPI_Win_flush(this->_self_rank, this->_last_win);
      MPI_Win_flush(this->_self_rank, this->_announce_win);
      MPI_Win_flush(this->_self_rank, this->_free_later_win);

      MPI_Aint new_last = (last + 1) % this->_size;
      if (new_last == first || last == announce || last == free_later) {
        MPI_Win_unlock_all(this->_first_win);
        MPI_Win_unlock_all(this->_last_win);
        MPI_Win_unlock_all(this->_announce_win);
        MPI_Win_unlock_all(this->_free_later_win);
        MPI_Win_unlock_all(this->_data_win);
        return false;
      }
      MPI_Put(&data, 1, this->_mpi_type, this->_self_rank, last, 1,
              this->_mpi_type, this->_data_win);
      MPI_Win_flush(this->_self_rank, this->_data_win);
      MPI_Accumulate(&new_last, 1, MPI_AINT, this->_self_rank, 0, 1, MPI_AINT,
                     MPI_REPLACE, this->_last_win);

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_announce_win);
      MPI_Win_unlock_all(this->_free_later_win);
      MPI_Win_unlock_all(this->_data_win);

      return true;
    }
  } _spsc;

public:
  LTEnqueuer(MPI_Comm comm, MPI_Datatype type, MPI_Aint size,
             MPI_Aint self_rank, MPI_Aint dequeuer_rank)
      : _mpi_type{type}, _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
        _spsc{comm, type, size, self_rank, dequeuer_rank} {
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_counter_ptr,
                     &this->_counter_win);
    MPI_Barrier(comm);
  }
  LTEnqueuer(const LTEnqueuer &) = delete;
  LTEnqueuer &operator=(const LTEnqueuer &) = delete;
  ~LTEnqueuer() {}

  bool enqueue(const T &data) {}
};

template <typename T> class LTDequeuer {
private:
  constexpr static MPI_Aint NULL_INDEX = ~((MPI_Aint)0);

  MPI_Datatype _mpi_type;
  MPI_Aint _self_rank;

  MPI_Win _counter_win;
  MPI_Aint *_counter_ptr;

  struct data_t {
    T data;
    std::uint64_t timestamp;
  };

  class Spsc {
    MPI_Datatype _mpi_type;
    MPI_Aint _self_rank;

    MPI_Aint _size;

    MPI_Win _data_win;
    data_t *_data_ptr;

    MPI_Win _first_win;
    MPI_Aint *_first_ptr;

    MPI_Win _last_win;
    MPI_Aint *_last_ptr;

    MPI_Win _announce_win;
    MPI_Aint *_announce_ptr;

    MPI_Win _free_later_win;
    MPI_Aint *_free_later_ptr;

    MPI_Win _help_win;
    data_t *_help_ptr;

  public:
    Spsc(MPI_Comm comm, MPI_Datatype original_type, MPI_Aint size,
         MPI_Aint self_rank)
        : _self_rank{self_rank}, _size{size} {
      int blocklengths[] = {1, 1};
      MPI_Datatype types[] = {original_type, MPI_UINT64_T};
      MPI_Aint offsets[2];
      offsets[0] = offsetof(data_t, data);
      offsets[1] = offsetof(data_t, timestamp);
      MPI_Type_create_struct(2, blocklengths, offsets, types, &this->_mpi_type);
      MPI_Type_commit(&this->_mpi_type);

      MPI_Info info;
      MPI_Info_create(&info);
      MPI_Info_set(info, "same_disp_unit", "true");

      MPI_Win_allocate(0, sizeof(data_t), info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_first_ptr,
                       &this->_first_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_last_ptr,
                       &this->_last_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_announce_ptr,
                       &this->_announce_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_free_later_ptr,
                       &this->_free_later_win);
      MPI_Win_allocate(0, sizeof(data_t), info, comm, &this->_help_ptr,
                       &this->_help_win);
      MPI_Barrier(comm);
    }

    ~Spsc() {
      MPI_Type_free(&this->_mpi_type);
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
      MPI_Win_free(&this->_announce_win);
      MPI_Win_free(&this->_free_later_win);
      MPI_Win_free(&this->_help_win);
    }

    void dequeue(data_t *&output, MPI_Aint enqueuer_rank) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_announce_win);
      MPI_Win_lock_all(0, this->_free_later_win);
      MPI_Win_lock_all(0, this->_data_win);

      MPI_Aint first;
      MPI_Aint last;
      MPI_Aint announce;
      MPI_Aint free_later;
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &first, 1, MPI_AINT, enqueuer_rank,
                         0, 1, MPI_AINT, MPI_NO_OP, this->_first_win);
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &last, 1, MPI_AINT, enqueuer_rank,
                         0, 1, MPI_AINT, MPI_NO_OP, this->_last_win);
      MPI_Win_flush(enqueuer_rank, this->_first_win);
      MPI_Win_flush(enqueuer_rank, this->_last_win);
      if (first == last) {
        output = NULL;
        MPI_Win_unlock_all(this->_first_win);
        MPI_Win_unlock_all(this->_last_win);
        MPI_Win_unlock_all(this->_announce_win);
        MPI_Win_unlock_all(this->_free_later_win);
        MPI_Win_unlock_all(this->_data_win);
        return;
      }

      MPI_Get(output, 1, this->_mpi_type, enqueuer_rank, first, 1,
              this->_mpi_type, this->_data_win);
      MPI_Win_flush(enqueuer_rank, this->_data_win);
      MPI_Accumulate(output, 1, this->_mpi_type, enqueuer_rank, 0, 1,
                     this->_mpi_type, MPI_REPLACE, this->_help_win);

      MPI_Aint new_first = (first + 1) % this->_size;
      MPI_Accumulate(&new_first, 1, MPI_AINT, enqueuer_rank, 0, 1, MPI_AINT,
                     MPI_REPLACE, this->_first_win);

      MPI_Get_accumulate(NULL, 0, MPI_AINT, &announce, 1, MPI_AINT,
                         enqueuer_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_announce_win);
      MPI_Win_flush(enqueuer_rank, this->_announce_win);
      if (first == announce) {
        MPI_Accumulate(&announce, 1, MPI_AINT, enqueuer_rank, 0, 1, MPI_AINT,
                       MPI_REPLACE, this->_free_later_win);
      }
      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_announce_win);
      MPI_Win_unlock_all(this->_free_later_win);
      MPI_Win_unlock_all(this->_data_win);
    }
  } _spsc;

public:
  LTDequeuer(MPI_Comm comm, MPI_Datatype type, MPI_Aint size,
             MPI_Aint self_rank)
      : _mpi_type{type}, _self_rank{self_rank},
        _spsc{comm, type, size, self_rank} {
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                     &this->_counter_ptr, &this->_counter_win);
    MPI_Win_lock_all(0, this->_counter_win);
    *this->_counter_ptr = 0;
    MPI_Win_unlock_all(this->_counter_win);
    MPI_Barrier(comm);
  }
  LTDequeuer(const LTDequeuer &) = delete;
  LTDequeuer &operator=(const LTDequeuer &) = delete;
  ~LTDequeuer() {}

  void dequeue(T *&output, MPI_Aint enqueuer_rank) {}
};
