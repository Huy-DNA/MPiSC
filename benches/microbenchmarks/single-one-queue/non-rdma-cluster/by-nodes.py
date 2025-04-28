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
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "LTQueue": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "FastQueue": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "SlotqueueV2a": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "SlotqueueV2b": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "SlotqueueV2bc": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "SlotqueueV2c": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
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
