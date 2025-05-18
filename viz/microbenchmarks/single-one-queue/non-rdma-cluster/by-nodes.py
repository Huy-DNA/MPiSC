import matplotlib.pyplot as plt
import os

output_dir = "non-rdma-cluster/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)
nodes = [1, 2, 3, 4]
queue_data = {
    "SlotQueue": {
        "dequeue_throughput": [1.56265, 0.13201, 0.115092, 0.0999554],
        "dequeue_latency": [6.39938, 75.7521, 86.8868, 100.045],
        "enqueue_throughput": [4.85393, 0.4833, 0.347113, 0.271415],
        "enqueue_latency": [14.4213, 310.366, 662.608, 1142.16],
        "total_throughput": [3.12577, 0.264085, 0.230242, 0.200041],
    },
    "dLTQueue": {
        "dequeue_throughput": [0.287441, 0.00543658, 0.00321616, 0.00235801],
        "dequeue_latency": [34.7898, 1839.39, 3109.3, 4240.87],
        "enqueue_throughput": [1.02183, 0.0270633, 0.0166776, 0.008472],
        "enqueue_latency": [68.5043, 5542.55, 13791, 36591.1],
        "total_throughput": [0.574968, 0.0108759, 0.00643392, 0.00471908],
    },
    "AMQueue": {
        "dequeue_throughput": [12.8275, 0.0898694, 0.0777419, 0.0728335],
        "dequeue_latency": [0.779574, 111.273, 128.631, 137.299],
        "enqueue_throughput": [13.2698, 0.169792, 0.112492, 0.0954702],
        "enqueue_latency": [5.27512, 883.432, 2044.59, 3247.09],
        "total_throughput": [25.6201, 0.179615, 0.155351, 0.145486],
    },
    "dJiffy": {
        "dequeue_throughput": [0.63589, 0.00396241, 0.00320866, 0.00317752],
        "dequeue_latency": [15.726, 2523.72, 3116.56, 3147.11],
        "enqueue_throughput": [1.10986, 0.13955, 0.0816475, 0.0666038],
        "enqueue_latency": [63.0711, 1074.88, 2816.99, 4654.39],
        "total_throughput": [1.27242, 0.00794463, 0.00645583, 0.00642811],
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
    "dJiffy": {"color": "green", "marker": "^"},
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
