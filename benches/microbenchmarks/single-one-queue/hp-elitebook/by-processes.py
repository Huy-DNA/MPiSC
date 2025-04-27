import matplotlib.pyplot as plt
import os

# Ensure the output directory exists
output_dir = "hp-elitebook/by-processes/"
os.makedirs(output_dir, exist_ok=True)

# Data for processors and queue types
processors = [2, 3, 4, 5, 6, 7, 8]

# Data for different queues and metrics
queue_data = {
    "SlotQueue": {
        "dequeue_throughput": [
            6.71694,
            5.62471,
            4.805,
            4.01714,
            3.43972,
            2.95834,
            2.55777,
        ],
        "dequeue_latency": [
            1.48877,
            1.77787,
            2.08117,
            2.48934,
            2.90721,
            3.38027,
            3.90965,
        ],
        "enqueue_throughput": [
            11.2303,
            19.1108,
            27.7972,
            27.544,
            32.8996,
            42.1485,
            44.6472,
        ],
        "enqueue_latency": [
            0.890451,
            1.04653,
            1.07925,
            1.45222,
            1.51978,
            1.42354,
            1.56785,
        ],
        "total_throughput": [
            13.4339,
            11.2495,
            9.61009,
            8.03443,
            6.87962,
            5.91674,
            5.11559,
        ],
    },
    "SlotqueueV2a": {
        "dequeue_throughput": [
            6.115,
            6.48122,
            6.51498,
            6.10462,
            5.88161,
            5.63608,
            5.38155,
        ],
        "dequeue_latency": [
            1.63532,
            1.54292,
            1.53492,
            1.6381,
            1.70022,
            1.77428,
            1.8582,
        ],
        "enqueue_throughput": [
            11.2648,
            21.5056,
            31.3342,
            31.7099,
            38.1587,
            44.1879,
            50.3359,
        ],
        "enqueue_latency": [
            0.887723,
            0.929989,
            0.957419,
            1.26144,
            1.31032,
            1.35784,
            1.39066,
        ],
        "total_throughput": [
            12.2301,
            12.9626,
            13.0301,
            12.2095,
            11.7635,
            11.2723,
            10.7632,
        ],
    },
    "SlotqueueV2b": {
        "dequeue_throughput": [
            7.0728,
            5.87548,
            4.93138,
            3.99007,
            3.34042,
            2.79585,
            2.41193,
        ],
        "dequeue_latency": [
            1.41387,
            1.70199,
            2.02783,
            2.50622,
            2.99363,
            3.57673,
            4.14606,
        ],
        "enqueue_throughput": [
            11.085,
            21.3826,
            30.9417,
            30.5781,
            36.8597,
            41.4068,
            45.6702,
        ],
        "enqueue_latency": [
            0.902119,
            0.935339,
            0.969567,
            1.30812,
            1.3565,
            1.44904,
            1.53273,
        ],
        "total_throughput": [
            14.1457,
            11.7511,
            9.86286,
            7.98031,
            6.68101,
            5.59175,
            4.8239,
        ],
    },
    "SlotqueueV2bc": {
        "dequeue_throughput": [
            7.70268,
            6.33303,
            5.21812,
            4.07562,
            3.40127,
            2.91672,
            2.5216,
        ],
        "dequeue_latency": [
            1.29825,
            1.57902,
            1.9164,
            2.45361,
            2.94008,
            3.42851,
            3.96573,
        ],
        "enqueue_throughput": [
            11.3038,
            21.3511,
            30.7712,
            29.1713,
            35.5137,
            41.272,
            45.8211,
        ],
        "enqueue_latency": [
            0.884661,
            0.936721,
            0.974939,
            1.37121,
            1.40791,
            1.45377,
            1.52768,
        ],
        "total_throughput": [
            15.4054,
            12.6662,
            10.4363,
            8.15141,
            6.80272,
            5.8335,
            5.04326,
        ],
    },
    "SlotqueueV2c": {
        "dequeue_throughput": [
            7.72584,
            6.26877,
            4.99455,
            4.06522,
            3.41399,
            2.88213,
            2.51016,
        ],
        "dequeue_latency": [
            1.29436,
            1.59521,
            2.00218,
            2.45989,
            2.92912,
            3.46966,
            3.9838,
        ],
        "enqueue_throughput": [
            11.3105,
            21.3425,
            29.9502,
            30.0831,
            36.2649,
            40.9888,
            48.8856,
        ],
        "enqueue_latency": [
            0.884135,
            0.937099,
            1.00166,
            1.32965,
            1.37874,
            1.46381,
            1.43191,
        ],
        "total_throughput": [
            15.4518,
            12.5377,
            9.98919,
            8.13059,
            6.82816,
            5.76431,
            5.02038,
        ],
    },
    "LTQueue": {
        "dequeue_throughput": [
            3.99498,
            3.02025,
            2.4074,
            1.6309,
            1.40859,
            1.12113,
            1.0478,
        ],
        "dequeue_latency": [
            2.50314,
            3.31099,
            4.15386,
            6.13157,
            7.09929,
            8.91953,
            9.54385,
        ],
        "enqueue_throughput": [
            4.01414,
            5.41144,
            6.15751,
            3.65075,
            3.3328,
            2.50958,
            2.40578,
        ],
        "enqueue_latency": [
            2.49119,
            3.69587,
            4.8721,
            10.9566,
            15.0024,
            23.9084,
            29.0965,
        ],
        "total_throughput": [
            7.99,
            6.04056,
            4.81485,
            3.26187,
            2.81725,
            2.24229,
            2.09561,
        ],
    },
    "FastQueue": {
        "dequeue_throughput": [
            25.8592,
            25.4871,
            23.2864,
            21.7602,
            20.7886,
            19.8802,
            18.4958,
        ],
        "dequeue_latency": [
            0.38671,
            0.392356,
            0.429436,
            0.459554,
            0.481032,
            0.503012,
            0.540662,
        ],
        "enqueue_throughput": [
            25.8118,
            47.7227,
            63.6327,
            59.2919,
            51.9272,
            43.9675,
            64.9094,
        ],
        "enqueue_latency": [
            0.38742,
            0.419088,
            0.471456,
            0.674628,
            0.962886,
            1.36464,
            1.07843,
        ],
        "total_throughput": [
            51.4025,
            50.9741,
            46.5727,
            43.5205,
            41.5773,
            39.7605,
            36.9917,
        ],
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
    "SlotqueueV2a": {"color": "purple", "marker": "d", "linestyle": "--"},
    "SlotqueueV2b": {"color": "cyan", "marker": "s", "linestyle": "--"},
    "SlotqueueV2bc": {"color": "magenta", "marker": "x", "linestyle": "--"},
    "SlotqueueV2c": {"color": "brown", "marker": "+", "linestyle": "--"},
    "LTQueue": {"color": "red", "marker": "s"},
    "FastQueue": {"color": "green", "marker": "^"},
}

# Generate merged plots for each metric
for metric in metrics:
    # Create a new figure for each metric
    plt.figure(figsize=(12, 7))

    # Plot data for each queue
    for queue_name, queue_metrics in queue_data.items():
        style = queue_styles[queue_name]
        plt.plot(
            processors,
            queue_metrics[metric],
            color=style["color"],
            marker=style["marker"],
            linestyle=style.get("linestyle", "-"),
            label=f"{queue_name}{'*' if 'V2a' in queue_name else ''}",
        )

    # Set title and labels
    title, unit = metric_labels[metric]
    plt.title(f"Comparative {title} Across Queue Implementations")
    plt.xlabel("Number of Processors")
    plt.ylabel(f"{title} ({unit})")

    # Add grid and legend
    plt.grid(True)
    plt.legend(title="Queue Types", loc="best")

    # Save the plot
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename)
    plt.close()  # Close the figure to free up memory

print(
    "All comparative plots have been generated in the 'hp-elitebook/by-processes' folder."
)
print(
    "Note: SlotqueueV2a are marked with an asterisk (*) in the legend to indicate they are experimental."
)
