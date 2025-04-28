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
        "dequeue_throughput": [1.12841, 0.0318714, 0.025549, 0.0199796],
        "dequeue_latency": [8.862, 313.761, 391.404, 500.51],
        "enqueue_throughput": [4.79747, 0.765893, 0.66733, 0.378026],
        "enqueue_latency": [14.591, 195.85, 344.657, 820.048],
        "total_throughput": [2.25796, 0.0639021, 0.0514047, 0.0404188],
    },
    "LTQueue": {
        "dequeue_throughput": [0.424427, 0.00682855, 0.00541103, 0.00414144],
        "dequeue_latency": [23.5612, 1464.44, 1848.08, 2414.62],
        "enqueue_throughput": [0.970297, 0.0302003, 0.0251621, 0.0170012],
        "enqueue_latency": [72.1429, 4966.83, 9140.75, 18234],
        "total_throughput": [0.849278, 0.0136912, 0.010887, 0.00837814],
    },
    "FastQueue": {
        "dequeue_throughput": [6.40287, 1.94303, 1.94182, 1.93633],
        "dequeue_latency": [1.5618, 5.1466, 5.1498, 5.1644],
        "enqueue_throughput": [4.26299, 0.54858, 0.437161, 0.340829],
        "enqueue_latency": [16.4204, 273.433, 526.121, 909.546],
        "total_throughput": [8.06712, 0.58171, 0.588145, 0.512203],
    },
    "SlotqueueV2a": {
        "dequeue_throughput": [1.47859, 0.0326036, 0.0255839, 0.0217996],
        "dequeue_latency": [6.7632, 306.714, 390.871, 458.725],
        "enqueue_throughput": [4.61825, 0.822099, 0.618566, 0.476086],
        "enqueue_latency": [15.1572, 182.46, 371.828, 651.143],
        "total_throughput": [2.95866, 0.0653703, 0.0514748, 0.0441005],
    },
    "SlotqueueV2b": {
        "dequeue_throughput": [1.16444, 0.0397495, 0.0352721, 0.0281847],
        "dequeue_latency": [8.5878, 251.575, 283.51, 354.803],
        "enqueue_throughput": [3.99715, 0.297802, 0.258851, 0.18849],
        "enqueue_latency": [17.5125, 503.691, 888.544, 1644.65],
        "total_throughput": [2.33005, 0.0796978, 0.0709675, 0.0570176],
    },
    "SlotqueueV2bc": {
        "dequeue_throughput": [1.30191, 0.105914, 0.103376, 0.0878917],
        "dequeue_latency": [7.681, 94.4166, 96.7338, 113.776],
        "enqueue_throughput": [3.95019, 0.29763, 0.244308, 0.177258],
        "enqueue_latency": [17.7207, 503.982, 941.435, 1748.87],
        "total_throughput": [2.60513, 0.212357, 0.207993, 0.177805],
    },
    "SlotqueueV2c": {
        "dequeue_throughput": [1.20337, 0.068702, 0.058669, 0.0487821],
        "dequeue_latency": [8.31, 145.556, 170.448, 204.993],
        "enqueue_throughput": [4.50501, 0.768201, 0.664723, 0.534115],
        "enqueue_latency": [15.5383, 195.261, 346.009, 580.399],
        "total_throughput": [2.40794, 0.137747, 0.118042, 0.0986861],
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
    plt.xlabel("Number of Nodes (x8 cores)")
    plt.ylabel(f"{title} ({unit})")

    # Add grid and legend
    plt.grid(True)
    plt.legend(title="Queue Types", loc="best")

    # Set x-axis to use only integer values
    plt.xticks(nodes, [str(int(node)) for node in nodes])

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
        if queue_name != "LTQueue":  # Exclude LTQueue for this set of plots
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
    plt.xlabel("Number of Nodes (x8 cores)")
    plt.ylabel(f"{title} ({unit})")

    # Add grid and legend
    plt.grid(True)
    plt.legend(title="Queue Types", loc="best")

    # Set x-axis to use only integer values
    plt.xticks(nodes, [str(int(node)) for node in nodes])

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
