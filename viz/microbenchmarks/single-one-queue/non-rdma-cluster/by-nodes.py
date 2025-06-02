import matplotlib.pyplot as plt
import os

output_dir = "non-rdma-cluster/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)

nodes = [1, 2, 3, 4]

queue_data = {
    "Slotqueue": {
        "dequeue_throughput": [1.11673, 0.13496, 0.126999, 0.125209],
        "dequeue_latency": [8.95474, 74.0962, 78.7411, 79.8664],
        "enqueue_throughput": [3.28671, 0.25411, 0.24775, 0.292371],
        "enqueue_latency": [21.2979, 590.295, 928.355, 1060.3],
        "total_throughput": [2.23379, 0.269987, 0.254061, 0.250581],
    },
    "Slotqueue Unbounded": {
        "dequeue_throughput": [0.560249, 0.0295915, 0.0217562, 0.0203315],
        "dequeue_latency": [17.8492, 337.935, 459.64, 491.848],
        "enqueue_throughput": [1.99281, 0.191586, 0.126274, 0.159169],
        "enqueue_latency": [35.1263, 782.938, 1821.43, 1947.61],
        "total_throughput": [1.12067, 0.0591978, 0.0435232, 0.0406894],
    },
    "LTQueue Unbounded": {
        "dequeue_throughput": [0.396487, 0.0259934, 0.0190773, 0.0172865],
        "dequeue_latency": [25.2215, 384.713, 524.184, 578.485],
        "enqueue_throughput": [1.82603, 0.198867, 0.125013, 0.15791],
        "enqueue_latency": [38.3345, 754.272, 1839.81, 1963.15],
        "total_throughput": [0.793093, 0.0519998, 0.0381641, 0.0345956],
    },
    "LTQueue": {
        "dequeue_throughput": [0.641118, 0.0943043, 0.067812, 0.0596622],
        "dequeue_latency": [15.5978, 106.04, 147.467, 167.61],
        "enqueue_throughput": [3.09808, 0.373965, 0.233022, 0.283175],
        "enqueue_latency": [22.5946, 401.107, 987.033, 1094.73],
        "total_throughput": [1.28243, 0.188656, 0.135658, 0.119402],
    },
    "Naive Jiffy": {
        "dequeue_throughput": [0.631239, 0.0425949, 0.0291597, 0.0438869],
        "dequeue_latency": [15.8419, 234.77, 342.939, 227.858],
        "enqueue_throughput": [1.01611, 0.106855, 0.0629367, 0.0889347],
        "enqueue_latency": [68.89, 1403.77, 3654.47, 3485.7],
        "total_throughput": [1.26267, 0.085211, 0.058334, 0.0878308],
    },
    "AMQueue": {
        "dequeue_throughput": [1.55844, 0.114101, 0.120557, 0.1624],
        "dequeue_latency": [6.41668, 87.6415, 82.9484, 61.5762],
        "enqueue_throughput": [1.65324, 0.170142, 0.12482, 0.164671],
        "enqueue_latency": [42.3411, 881.615, 1842.65, 1882.54],
        "total_throughput": [3.10339, 0.222947, 0.237143, 0.317361],
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
    "Slotqueue": {"color": "blue", "marker": "o"},
    "Slotqueue Unbounded": {"color": "lightblue", "marker": "o", "linestyle": "--"},
    "LTQueue Unbounded": {"color": "lightcoral", "marker": "s", "linestyle": "--"},
    "LTQueue": {"color": "red", "marker": "s"},
    "Naive Jiffy": {"color": "green", "marker": "^"},
    "AMQueue": {"color": "purple", "marker": "d"},
}

for metric in metrics:
    plt.figure(figsize=(12, 7))

    for queue_name, queue_metrics in queue_data.items():
        style = queue_styles[queue_name]
        linestyle = style.get("linestyle", "-")

        plt.plot(
            nodes,
            queue_metrics[metric],
            color=style["color"],
            marker=style["marker"],
            linestyle=linestyle,
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
