#include <mpi.h>
#include <extrae_user_events.h>
#include <chrono>
#include <cmath>
#include <numeric>
#include <vector>
#include <iostream>
#include <array>

namespace {
constexpr extrae_type_t COMPUTE_EVENT = 1001;
constexpr extrae_value_t PHASE_STENCIL = 1;
constexpr extrae_value_t PHASE_REDUCTION = 2;
constexpr extrae_value_t PHASE_WAIT = 3;

void busy_compute(std::size_t iters) {
    double acc = 0.0;
    for (std::size_t i = 0; i < iters; ++i) {
        acc += std::sin(static_cast<double>(i));
    }
    // prevent compiler from optimizing the loop out entirely
    if (acc < 0.0) {
        std::fprintf(stderr, "acc=%f\n", acc);
    }
}
}

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int world_rank = 0;
    int world_size = 0;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    bool owns_extrae = (Extrae_is_initialized() == EXTRAE_NOT_INITIALIZED);
    if (owns_extrae) {
        Extrae_init();
    }

    unsigned value_count = 3;
    std::array<extrae_value_t, 3> values = {PHASE_STENCIL, PHASE_REDUCTION, PHASE_WAIT};
    std::array<char*, 3> labels = {
        const_cast<char*>("Compute stencil"),
        const_cast<char*>("Global reduction"),
        const_cast<char*>("Halo wait")
    };
    extrae_type_t type = COMPUTE_EVENT;
    Extrae_define_event_type(&type, const_cast<char*>("Demo phases"), &value_count, values.data(), labels.data());

    std::size_t local_size = 500000; // tune so the trace is short but visible
    std::vector<double> data(local_size, world_rank + 1.0);

    auto start = std::chrono::steady_clock::now();

    Extrae_event(COMPUTE_EVENT, PHASE_STENCIL);
    busy_compute(local_size / 10);

    std::vector<double> halo(2, 0.0);
    double send_left = data.front();
    double send_right = data.back();
    int left = (world_rank - 1 + world_size) % world_size;
    int right = (world_rank + 1) % world_size;

    MPI_Request reqs[4];
    MPI_Irecv(&halo[0], 1, MPI_DOUBLE, left, 0, MPI_COMM_WORLD, &reqs[0]);
    MPI_Irecv(&halo[1], 1, MPI_DOUBLE, right, 1, MPI_COMM_WORLD, &reqs[1]);
    MPI_Isend(&send_left, 1, MPI_DOUBLE, left, 1, MPI_COMM_WORLD, &reqs[2]);
    MPI_Isend(&send_right, 1, MPI_DOUBLE, right, 0, MPI_COMM_WORLD, &reqs[3]);

    Extrae_event(COMPUTE_EVENT, PHASE_WAIT);
    MPI_Waitall(4, reqs, MPI_STATUSES_IGNORE);

    data.front() = (data.front() + halo[0]) * 0.5;
    data.back() = (data.back() + halo[1]) * 0.5;

    Extrae_event(COMPUTE_EVENT, PHASE_REDUCTION);
    double local_sum = std::accumulate(data.begin(), data.end(), 0.0);
    double global_sum = 0.0;
    MPI_Allreduce(&local_sum, &global_sum, 1, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);

    auto end = std::chrono::steady_clock::now();
    double elapsed = std::chrono::duration<double>(end - start).count();

    if (world_rank == 0) {
        std::cout << "Global sum: " << global_sum
                  << ", elapsed: " << elapsed << " s" << std::endl;
    }

    Extrae_event(COMPUTE_EVENT, 0);
    MPI_Finalize();
    return 0;
}
