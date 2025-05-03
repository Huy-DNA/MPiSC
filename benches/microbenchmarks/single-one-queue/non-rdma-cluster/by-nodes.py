import matplotlib.pyplot as plt
import os

# Ensure the output directory exists
output_dir = "non-rdma-cluster/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)

# Data for nodes and queue types
nodes = [1, 2, 3]

# Data for different queues and metrics
queue_data = {
    "SlotQueue + custom SPSC": {
        "dequeue_throughput": [2.20109, 0.135365, 0.125881],
        "dequeue_latency": [4.5432, 73.8744, 79.4398],
        "enqueue_throughput": [5.27636, 0.366896, 0.272167],
        "enqueue_latency": [13.2667, 408.836, 845.069],
        "total_throughput": [4.40438, 0.271407, 0.253274],
    },
    "LTQueue + custom SPSC": {
        "dequeue_throughput": [0.526565, 0.00716466, 0.00532755],
        "dequeue_latency": [18.991, 1395.74, 1877.03],
        "enqueue_throughput": [1.09137, 0.0302231, 0.0261331],
        "enqueue_latency": [64.1395, 4963.1, 8801.12],
        "total_throughput": [1.05366, 0.0143651, 0.010719],
    },
    "AMQueue": {
        "dequeue_throughput": [13.5767, 0.0660331, 0.0895714],
        "dequeue_latency": [0.736558, 151.439, 111.643],
        "enqueue_throughput": [13.3691, 0.123752, 0.123568],
        "enqueue_latency": [5.23596, 1212.1, 1861.32],
        "total_throughput": [24.4934, 0.124142, 0.163123],
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
    "SlotQueue + custom SPSC": {"color": "blue", "marker": "o"},
    "LTQueue + custom SPSC": {"color": "red", "marker": "s"},
    "AMQueue": {"color": "purple", "marker": "d"},
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
            linestyle="-",
            label=queue_name,
            linewidth=2,
            markersize=8,
        )

    # Set title and labels
    title, unit = metric_labels[metric]
    plt.title(f"Comparative {title} Across Queue Implementations", fontsize=16)
    plt.xlabel("Number of Nodes (x8 cores)", fontsize=14)
    plt.ylabel(f"{title} ({unit})", fontsize=14)

    # Add grid and legend
    plt.grid(True, alpha=0.3)
    plt.legend(title="Queue Types", loc="best", fontsize=12)

    # Set x-axis to use only integer values
    plt.xticks(nodes, [str(int(node)) for node in nodes], fontsize=12)
    plt.yticks(fontsize=12)

    # Add a tight layout to make better use of space
    plt.tight_layout()

    # Save the plot
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename, dpi=300)
    plt.close()  # Close the figure to free up memory

print(
    "All comparative plots have been generated in the 'non-rdma-cluster/all/by-nodes' folder."
)

# Generate separate plots for each metric excluding LTQueue (which has much worse performance)
output_dir = "non-rdma-cluster/no-ltqueue/by-nodes"
os.makedirs(output_dir, exist_ok=True)

for metric in metrics:
    # Create a new figure for each metric
    plt.figure(figsize=(12, 7))

    # Plot data for each queue
    for queue_name, queue_metrics in queue_data.items():
        if queue_name != "LTQueue + custom SPSC":  # Exclude LTQueue for this set of plots
            style = queue_styles[queue_name]
            plt.plot(
                nodes,
                queue_metrics[metric],
                color=style["color"],
                marker=style["marker"],
                linestyle="-",
                label=queue_name,
                linewidth=2,
                markersize=8,
            )

    # Set title and labels
    title, unit = metric_labels[metric]
    plt.title(
        f"Comparative {title} Across Queue Implementations (Excluding LTQueue)",
        fontsize=16,
    )
    plt.xlabel("Number of Nodes (x8 cores)", fontsize=14)
    plt.ylabel(f"{title} ({unit})", fontsize=14)

    # Add grid and legend
    plt.grid(True, alpha=0.3)
    plt.legend(title="Queue Types", loc="best", fontsize=12)

    # Set x-axis to use only integer values
    plt.xticks(nodes, [str(int(node)) for node in nodes], fontsize=12)
    plt.yticks(fontsize=12)

    # Add a tight layout to make better use of space
    plt.tight_layout()

    # Save the plot
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename, dpi=300)
    plt.close()  # Close the figure to free up memory

print(
    "All comparative plots have been generated in the 'non-rdma-cluster/no-ltqueue/by-nodes' folder."
)
