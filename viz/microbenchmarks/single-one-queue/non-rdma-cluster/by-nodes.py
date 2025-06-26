import matplotlib.pyplot as plt
import os

output_dir = "non-rdma-cluster/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)

nodes = [2, 4, 8, 16]

queue_data = {
    "Slotqueue": {
        "dequeue_throughput": [0.123338, 0.0886871, 0.0859344, 0.0321722],
        "dequeue_latency": [81.0777, 112.756, 116.368, 310.827],
        "enqueue_throughput": [0.434409, 0.219555, 0.227658, 0.0769318],
        "enqueue_latency": [345.297, 1411.95, 2767.31, 14428.4],
        "total_throughput": [0.246739, 0.17749, 0.172015, 0.0646694],
    },
    "Slotqueue Unbounded": {
        "dequeue_throughput": [0.0329554, 0.0245775, 0.022118, 0.0114818],
        "dequeue_latency": [303.44, 406.876, 452.121, 870.941],
        "enqueue_throughput": [0.240112, 0.117672, 0.141216, 0.0544276],
        "enqueue_latency": [624.708, 2634.43, 4461.26, 20394.1],
        "total_throughput": [0.0659273, 0.049187, 0.0442736, 0.0230796],
    },
    "Slotqueue Node": {
        "dequeue_throughput": [0.119177, 0.0859209, 0.0850357, 0.032532],
        "dequeue_latency": [83.9089, 116.386, 117.598, 307.389],
        "enqueue_throughput": [0.40559, 0.200152, 0.216819, 0.0788124],
        "enqueue_latency": [369.832, 1548.83, 2905.65, 14084.1],
        "total_throughput": [0.238413, 0.171953, 0.170216, 0.0653927],
    },
    "LTQueue": {
        "dequeue_throughput": [0.0747161, 0.0555336, 0.0531371, 0.0307168],
        "dequeue_latency": [133.84, 180.071, 188.192, 325.555],
        "enqueue_throughput": [0.432206, 0.201807, 0.2036, 0.0830857],
        "enqueue_latency": [347.057, 1536.12, 3094.3, 13359.7],
        "total_throughput": [0.14947, 0.111139, 0.106365, 0.0617439],
    },
    "LTQueue Unbounded": {
        "dequeue_throughput": [0.0285561, 0.020949, 0.0185049, 0.00861195],
        "dequeue_latency": [350.188, 477.349, 540.396, 1161.18],
        "enqueue_throughput": [0.239198, 0.119468, 0.115864, 0.0446594],
        "enqueue_latency": [627.094, 2594.83, 5437.43, 24854.8],
        "total_throughput": [0.0571265, 0.0419253, 0.0370413, 0.0173109],
    },
    "LTQueue Node": {
        "dequeue_throughput": [0.0751723, 0.0556122, 0.0535708, 0.0244206],
        "dequeue_latency": [133.028, 179.817, 186.669, 409.49],
        "enqueue_throughput": [0.445996, 0.207893, 0.206572, 0.0668192],
        "enqueue_latency": [336.326, 1491.15, 3049.79, 16612],
        "total_throughput": [0.150382, 0.111297, 0.107233, 0.0490879],
    },
    "Naive LTQueue Unbounded": {
        "dequeue_throughput": [0.00961319, 0.00595729, 0.00459748, 0.00217857],
        "dequeue_latency": [1040.24, 1678.62, 2175.11, 4590.16],
        "enqueue_throughput": [0.239012, 0.123267, 0.123647, 0.0457509],
        "enqueue_latency": [627.583, 2514.87, 5095.16, 24261.8],
        "total_throughput": [0.0192312, 0.0119223, 0.00920277, 0.00437915],
    },
    "AMQueue": {
        "dequeue_throughput": [0.0924691, 0.0642197, 0.0888117, 0.0443103],
        "dequeue_latency": [108.144, 155.716, 112.598, 225.681],
        "enqueue_throughput": [0.179493, 0.0866457, 0.0993492, 0.045654],
        "enqueue_latency": [835.686, 3577.79, 6341.27, 24313.3],
        "total_throughput": [0.183541, 0.127049, 0.173112, 0.0841107],
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
    "Slotqueue Node": {"color": "darkblue", "marker": "o", "linestyle": "-."},
    "LTQueue": {"color": "red", "marker": "s"},
    "LTQueue Unbounded": {"color": "lightcoral", "marker": "s", "linestyle": "--"},
    "LTQueue Node": {"color": "darkred", "marker": "s", "linestyle": "-."},
    "Naive LTQueue Unbounded": {"color": "green", "marker": "^"},
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

