import matplotlib.pyplot as plt
import os


output_dir = "non-rdma-cluster/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)


nodes = [1, 2, 3, 4]


queue_data = {
    "SlotQueue": {
        "dequeue_throughput": [2.28686, 0.145148, 0.13778, 0.0937151],
        "dequeue_latency": [4.3728, 68.895, 72.5794, 106.706],
        "enqueue_throughput": [4.12516, 0.408411, 0.334599, 0.208068],
        "enqueue_latency": [16.969, 367.277, 687.389, 1489.9],
        "total_throughput": [4.57602, 0.291023, 0.277214, 0.189586],
    },
    "LTQueue": {
        "dequeue_throughput": [0.896732, 0.00953929, 0.00651412, 0.00442806],
        "dequeue_latency": [11.1516, 1048.3, 1535.13, 2248.52],
        "enqueue_throughput": [4.33988, 0.354412, 0.283816, 0.22764],
        "enqueue_latency": [16.1295, 423.237, 810.385, 1298.31],
        "total_throughput": [1.79436, 0.0191263, 0.0131064, 0.00898238],
    },
    "AMQueue": {
        "dequeue_throughput": [11.0004, 0.076829, 0.0851223, 0.079559],
        "dequeue_latency": [0.909055, 130.159, 117.478, 120.7575],
        "enqueue_throughput": [12.6034, 0.14456, 0.117427, 0.0801075],
        "enqueue_latency": [5.55405, 1037.63, 1958.67, 3000.0],
        "total_throughput": [20.3126, 0.143949, 0.155033, 0.186766],
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
    "LTQueue": {"color": "red", "marker": "s"},
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
