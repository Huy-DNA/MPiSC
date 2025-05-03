import matplotlib.pyplot as plt
import os

# Ensure the output directory exists
output_dir = "non-rdma-cluster/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)

# Data for nodes and queue types
nodes = [1, 2, 3, 4]

# Data for different queues and metrics
queue_data = {
    "SlotQueue + our custom SPSC": {
        "dequeue_throughput": [1.42519, 0.139075, 0.106517, 0.0937151],
        "dequeue_latency": [7.0166, 71.9036, 93.8814, 106.706],
        "enqueue_throughput": [4.53904, 0.469878, 0.260319, 0.208068],
        "enqueue_latency": [15.4218, 319.232, 883.531, 1489.9],
        "total_throughput": [2.85181, 0.278846, 0.214313, 0.189586],
    },
    "LTQueue + our custom SPSC": {
        "dequeue_throughput": [0.429609, 0.0073331, 0.00506922, 0.00420328],
        "dequeue_latency": [23.277, 1363.68, 1972.69, 2379.1],
        "enqueue_throughput": [1.01365, 0.0318447, 0.0237135, 0.0169779],
        "enqueue_latency": [69.0573, 4710.36, 9699.1, 18259.1],
        "total_throughput": [0.859647, 0.0147029, 0.0101993, 0.00850323],
    },
    "FastQueue": {
        "dequeue_throughput": [6.29168, 1.8535, 1.84393, 1.94522],
        "dequeue_latency": [1.5894, 5.3952, 5.4232, 5.1408],
        "enqueue_throughput": [4.89333, 0.496313, 0.346763, 0.314497],
        "enqueue_latency": [14.3052, 302.229, 663.278, 985.7],
        "total_throughput": [9.23361, 0.509056, 0.47709, 0.478288],
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
    "SlotQueue + our custom SPSC": {"color": "blue", "marker": "o"},
    "LTQueue + our custom SPSC": {"color": "red", "marker": "s"},
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
            label=queue_name,
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
    plt.savefig(filename, dpi=300)
    plt.close()  # Close the figure to free up memory

print(
    "All comparative plots have been generated in the 'non-rdma-cluster/all/by-nodes' folder."
)

# Ensure the output directory exists for the second set of plots
output_dir = "non-rdma-cluster/no-ltqueue/by-nodes"
os.makedirs(output_dir, exist_ok=True)

# Generate merged plots for each metric (excluding LTQueue)
for metric in metrics:
    # Create a new figure for each metric
    plt.figure(figsize=(12, 7))

    # Plot data for each queue
    for queue_name, queue_metrics in queue_data.items():
        if (
            queue_name != "LTQueue + our custom SPSC"
        ):  # Exclude LTQueue for this set of plots
            style = queue_styles[queue_name]
            plt.plot(
                nodes,
                queue_metrics[metric],
                color=style["color"],
                marker=style["marker"],
                linestyle=style.get("linestyle", "-"),
                label=queue_name,
            )

    # Set title and labels
    title, unit = metric_labels[metric]
    plt.title(f"Comparative {title} Across Queue Implementations (Excluding LTQueue)")
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
