import matplotlib.pyplot as plt
import os

output_dir = "non-rdma-cluster/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)

nodes = [1, 2, 3, 4]

queue_data = {
    "SlotQueue": {
        "dequeue_throughput": [1.57149, 0.149915, 0.129626, 0.117402],
        "dequeue_latency": [6.3634, 66.7044, 77.1452, 85.1772],
        "enqueue_throughput": [4.66741, 0.414245, 0.270233, 0.234497],
        "enqueue_latency": [14.9976, 362.104, 851.116, 1321.98],
        "total_throughput": [3.14455, 0.30058, 0.260807, 0.237505],
    },
    "dLTQueue": {
        "dequeue_throughput": [0.287441, 0.00543658, 0.00321616, 0.00235801],
        "dequeue_latency": [34.7898, 1839.39, 3109.3, 4240.87],
        "enqueue_throughput": [1.02183, 0.0270633, 0.0166776, 0.008472],
        "enqueue_latency": [68.5043, 5542.55, 13791, 36591.1],
        "total_throughput": [0.574968, 0.0108759, 0.00643392, 0.00471908],
    },
    "AMQueue": {
        "dequeue_throughput": [11.4077, 0.0946985, 0.0697346, 0.0919903],
        "dequeue_latency": [0.8766, 105.598, 143.401, 108.707],
        "enqueue_throughput": [14.0963, 0.17869, 0.0954709, 0.109493],
        "enqueue_latency": [4.96583, 839.444, 2409.11, 2831.23],
        "total_throughput": [20.7573, 0.177045, 0.127443, 0.162925],
    },
}

metrics = [
    "dequeue_throughput",
    "dequeue_latency",
    "enqueue_throughput",
    "enqueue_latency",
    "total_throughput",
]

metric_labels = {
    "dequeue_throughput": ("Dequeue Throughput", "10^5 ops/s"),
    "dequeue_latency": ("Dequeue Latency", "μs"),
    "enqueue_throughput": ("Enqueue Throughput", "10^5 ops/s"),
    "enqueue_latency": ("Enqueue Latency", "μs"),
    "total_throughput": ("Total Throughput", "10^5 ops/s"),
}

queue_styles = {
    "SlotQueue": {"color": "blue", "marker": "o"},
    "dLTQueue": {"color": "red", "marker": "s"},
    "AMQueue": {"color": "purple", "marker": "d"},
}

for metric in metrics:
    plt.figure(figsize=(12, 7))

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

    title, unit = metric_labels[metric]
    plt.title(f"Comparative {title} Across Queue Implementations", fontsize=16)
    plt.xlabel("Number of Nodes (x8 cores)", fontsize=14)
    plt.ylabel(f"{title} ({unit})", fontsize=14)

    plt.yscale("log")  # Set y-axis to logarithmic scale
    plt.grid(True, alpha=0.3)
    plt.legend(title="Queue Types", loc="best", fontsize=12)

    plt.xticks(nodes, [str(int(node)) for node in nodes], fontsize=12)
    plt.yticks(fontsize=12)

    plt.tight_layout()

    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename, dpi=300)
    plt.close()

print(
    "All comparative plots have been generated in the 'non-rdma-cluster/all/by-nodes' folder."
)
