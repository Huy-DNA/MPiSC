import matplotlib.pyplot as plt
import os

# Ensure the output directory exists
output_dir = "non-rdma-cluster/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)
# Data for nodes and queue types
nodes = [1, 2, 3, 4]
# Data for different queues and metrics
queue_data = {
    "SlotQueue": {
        "dequeue_throughput": [0.726147, 0.0293738, 0.0217758, 0.0192054],
        "dequeue_latency": [13.7713, 340.439, 459.225, 520.686],
        "enqueue_throughput": [3.47734, 0.74881, 0.461881, 0.325011],
        "enqueue_latency": [20.1303, 200.318, 497.963, 953.813],
        "total_throughput": [1.45251, 0.0587623, 0.0435625, 0.0384358],
    },
    "LTQueue": {
        "dequeue_throughput": [0.287441, 0.00543658, 0.00321616, 0.00235801],
        "dequeue_latency": [34.7898, 1839.39, 3109.3, 4240.87],
        "enqueue_throughput": [1.02183, 0.0270633, 0.0166776, 0.008472],
        "enqueue_latency": [68.5043, 5542.55, 13791, 36591.1],
        "total_throughput": [0.574968, 0.0108759, 0.00643392, 0.00471908],
    },
    "FastQueue": {
        "dequeue_throughput": [1.54933, 0.150495, 0.115466, 0.0857726],
        "dequeue_latency": [6.4544, 66.4472, 86.606, 116.587],
        "enqueue_throughput": [2.54597, 0.288891, 0.171818, 0.114019],
        "enqueue_latency": [27.4944, 519.227, 1338.63, 2718.84],
        "total_throughput": [3.09913, 0.300745, 0.230989, 0.171657],
    },
    "SlotqueueV2a": {
        "dequeue_throughput": [1.07577, 0.0310169, 0.0227691, 0.0194541],
        "dequeue_latency": [9.29564, 322.405, 439.192, 514.03],
        "enqueue_throughput": [3.52285, 0.793044, 0.524294, 0.313851],
        "enqueue_latency": [19.8702, 189.145, 438.685, 987.731],
        "total_throughput": [2.15187, 0.0620492, 0.0455495, 0.0389335],
    },
    "SlotqueueV2b": {
        "dequeue_throughput": [0.765691, 0.0360893, 0.0269624, 0.0225218],
        "dequeue_latency": [13.0601, 277.09, 370.886, 444.014],
        "enqueue_throughput": [2.85764, 0.293864, 0.19904, 0.117019],
        "enqueue_latency": [24.4958, 510.439, 1155.55, 2649.13],
        "total_throughput": [1.53161, 0.0721966, 0.0539384, 0.0450729],
    },
    "SlotqueueV2bc": {
        "dequeue_throughput": [1.10123, 0.0991628, 0.0752016, 0.0555387],
        "dequeue_latency": [9.08077, 100.844, 132.976, 180.055],
        "enqueue_throughput": [2.85814, 0.296355, 0.188985, 0.110019],
        "enqueue_latency": [24.4914, 506.15, 1217.03, 2817.71],
        "total_throughput": [2.20279, 0.198375, 0.150441, 0.11115],
    },
    "SlotqueueV2c": {
        "dequeue_throughput": [0.893255, 0.0620864, 0.0421253, 0.036788],
        "dequeue_latency": [11.195, 161.066, 237.387, 271.827],
        "enqueue_throughput": [3.282, 0.693745, 0.476625, 0.259822],
        "enqueue_latency": [21.3284, 216.218, 482.56, 1193.12],
        "total_throughput": [1.78678, 0.124204, 0.0842716, 0.0736239],
    },
}
# Metrics to plot
metrics = [
    "dequeue_throughput",
    "dequeue_latency",
    "enqueue_throughput",
    "enqueue_latency",
    "total_throughput",
]
# Metric labels and units
metric_labels = {
    "dequeue_throughput": ("Dequeue Throughput", "10^5 ops/s"),
    "dequeue_latency": ("Dequeue Latency", "μs"),
    "enqueue_throughput": ("Enqueue Throughput", "10^5 ops/s"),
    "enqueue_latency": ("Enqueue Latency", "μs"),
    "total_throughput": ("Total Throughput", "10^5 ops/s"),
}
# Color and marker styles for each queue
queue_styles = {
    "SlotQueue": {"color": "blue", "marker": "o"},
    "LTQueue": {"color": "red", "marker": "s"},
    "FastQueue": {"color": "green", "marker": "^"},
    "SlotqueueV2a": {"color": "purple", "marker": "d", "linestyle": "--"},
    "SlotqueueV2b": {"color": "orange", "marker": "x"},
    "SlotqueueV2bc": {"color": "brown", "marker": "p"},
    "SlotqueueV2c": {"color": "cyan", "marker": "*"},
}
# Generate merged plots for each metric
for metric in metrics:
    # Create a new figure for each metric
    plt.figure(figsize=(12, 7))
    # Plot data for each queue
    for queue_name, queue_metrics in queue_data.items():
        style = queue_styles[queue_name]
        plt.plot(
            nodes,
            queue_metrics[metric],
            color=style["color"],
            marker=style["marker"],
            linestyle=style.get("linestyle", "-"),
            label=f"{queue_name}{'*' if queue_name == 'SlotqueueV2a' else ''}",
        )
    # Set title and labels
    title, unit = metric_labels[metric]
    plt.title(f"Comparative {title} Across Queue Implementations")
    plt.xlabel("Number of Nodes")
    plt.ylabel(f"{title} ({unit})")
    # Add grid and legend
    plt.grid(True)
    plt.legend(title="Queue Types", loc="best")
    # Save the plot
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename)
    plt.close()  # Close the figure to free up memory
print(
    "All comparative plots have been generated in the 'non-rdma-cluster/all/by-nodes' folder."
)
print(
    "Note: SlotqueueV2a is marked with an asterisk (*) in the legend to indicate it is experimental."
)
# Ensure the output directory exists
output_dir = "non-rdma-cluster/no-ltqueue/by-nodes/"
os.makedirs(output_dir, exist_ok=True)

# Generate merged plots for each metric
for metric in metrics:
    # Create a new figure for each metric
    plt.figure(figsize=(14, 8))

    # Plot data for each queue
    for queue_name, queue_metrics in queue_data.items():
        if queue_name != "LTQueue + baseline SPSC":
            style = queue_styles[queue_name]
            plt.plot(
                nodes,
                queue_metrics[metric],
                color=style["color"],
                marker=style["marker"],
                linestyle=style.get("linestyle", "-"),
                label=f"{queue_name}{'*' if queue_name == 'SlotqueueV2a' else ''}",
            )

    # Set title and labels
    title, unit = metric_labels[metric]
    plt.title(f"Comparative {title} Across Queue Implementations (1-4 Nodes)")
    plt.xlabel("Number of Nodes")
    plt.ylabel(f"{title} ({unit})")

    # Add grid and legend
    plt.grid(True)
    plt.legend(title="Queue Types", loc="best")

    # Add x-axis ticks for every processor count
    plt.xticks(nodes)

    # Save the plot
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename, dpi=300)
    plt.close()  # Close the figure to free up memory

print(
    "All comparative plots have been generated in the 'non-rdma-cluster/no-ltqueue/by-nodes' folder."
)

print(
    "Note: SlotqueueV2a is marked with an asterisk (*) in the legend to indicate it is experimental."
)
