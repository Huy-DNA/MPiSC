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
            6.67718,
            5.64286,
            4.7479,
            4.08801,
            3.40321,
            2.95691,
            2.58294,
        ],
        "dequeue_latency": [
            1.49764,
            1.77215,
            2.10619,
            2.44618,
            2.9384,
            3.38191,
            3.87155,
        ],
        "enqueue_throughput": [
            10.4269,
            19.7623,
            27.7697,
            26.6009,
            35.0253,
            39.8154,
            44.5943,
        ],
        "enqueue_latency": [
            0.95906,
            1.01203,
            1.08031,
            1.50371,
            1.42754,
            1.50696,
            1.56971,
        ],
        "total_throughput": [
            13.3544,
            11.2858,
            9.4959,
            8.17619,
            6.80659,
            5.91387,
            5.16594,
        ],
    },
    "SlotqueueV2a": {
        "dequeue_throughput": [
            6.17842,
            6.46362,
            6.18931,
            5.95259,
            5.64134,
            5.43952,
            5.42744,
        ],
        "dequeue_latency": [
            1.61854,
            1.54712,
            1.61569,
            1.67994,
            1.77263,
            1.8384,
            1.84249,
        ],
        "enqueue_throughput": [
            11.3388,
            21.5506,
            29.2939,
            31.0029,
            36.6669,
            42.0209,
            51.0184,
        ],
        "enqueue_latency": [
            0.881925,
            0.928049,
            1.0241,
            1.2902,
            1.36363,
            1.42786,
            1.37205,
        ],
        "total_throughput": [
            12.3569,
            12.9274,
            12.3787,
            11.9054,
            11.283,
            10.8791,
            10.855,
        ],
    },
    "SlotqueueV2b": {
        "dequeue_throughput": [
            7.0434,
            5.88594,
            4.64072,
            3.98104,
            3.21875,
            2.76478,
            2.25672,
        ],
        "dequeue_latency": [1.41977, 1.69896, 2.15484, 2.5119, 3.1068, 3.61693, 4.4312],
        "enqueue_throughput": [
            11.2159,
            21.5474,
            29.0542,
            28.9847,
            35.2385,
            40.0195,
            42.399,
        ],
        "enqueue_latency": [
            0.891595,
            0.928187,
            1.03255,
            1.38004,
            1.4189,
            1.49927,
            1.65098,
        ],
        "total_throughput": [
            14.0869,
            11.772,
            9.28153,
            7.96225,
            6.43766,
            5.52961,
            4.51349,
        ],
    },
    "SlotqueueV2bc": {
        "dequeue_throughput": [
            7.6546,
            6.26307,
            4.93122,
            4.10182,
            3.44118,
            2.92668,
            2.37922,
        ],
        "dequeue_latency": [
            1.3064,
            1.59666,
            2.0279,
            2.43794,
            2.90598,
            3.41684,
            4.20306,
        ],
        "enqueue_throughput": [
            11.1612,
            21.0274,
            28.7445,
            29.5103,
            35.5035,
            41.2291,
            38.6942,
        ],
        "enqueue_latency": [
            0.895957,
            0.951139,
            1.04368,
            1.35546,
            1.40831,
            1.45528,
            1.80906,
        ],
        "total_throughput": [
            15.3093,
            12.5263,
            9.86254,
            8.2038,
            6.88253,
            5.85342,
            4.75848,
        ],
    },
    "SlotqueueV2c": {
        "dequeue_throughput": [
            7.68683,
            6.27061,
            4.71916,
            4.08725,
            3.36417,
            2.89652,
            2.52062,
        ],
        "dequeue_latency": [
            1.30093,
            1.59474,
            2.11902,
            2.44663,
            2.9725,
            3.45242,
            3.96727,
        ],
        "enqueue_throughput": [
            11.265,
            21.0791,
            27.884,
            29.7982,
            35.1721,
            43.7521,
            49.0459,
        ],
        "enqueue_latency": [
            0.887709,
            0.948809,
            1.07588,
            1.34236,
            1.42158,
            1.37136,
            1.42723,
        ],
        "total_throughput": [
            15.3737,
            12.5414,
            9.43841,
            8.17467,
            6.72851,
            5.7931,
            5.0413,
        ],
    },
    "LTQueue": {
        "dequeue_throughput": [
            4.01163,
            3.07292,
            2.44023,
            1.69568,
            1.39299,
            1.1662,
            1.02359,
        ],
        "dequeue_latency": [
            2.49275,
            3.25423,
            4.09798,
            5.89733,
            7.17881,
            8.57485,
            9.76955,
        ],
        "enqueue_throughput": [
            4.01821,
            5.06714,
            5.92925,
            3.63416,
            3.11297,
            2.56518,
            2.2838,
        ],
        "enqueue_latency": [
            2.48867,
            3.947,
            5.05966,
            11.0067,
            16.0618,
            23.3902,
            30.6506,
        ],
        "total_throughput": [
            8.02329,
            6.1459,
            4.8805,
            3.39143,
            2.78605,
            2.33243,
            2.0472,
        ],
    },
    "FastQueue": {
        "dequeue_throughput": [
            26.0517,
            23.0642,
            23.4089,
            22.7119,
            21.4114,
            19.6422,
            18.5517,
        ],
        "dequeue_latency": [
            0.383852,
            0.433572,
            0.427188,
            0.440298,
            0.46704,
            0.509108,
            0.539034,
        ],
        "enqueue_throughput": [
            25.8387,
            44.7363,
            54.8101,
            60.811,
            51.8185,
            43.6506,
            46.7779,
        ],
        "enqueue_latency": [
            0.387016,
            0.447064,
            0.547344,
            0.657776,
            0.964906,
            1.37455,
            1.49643,
        ],
        "total_throughput": [
            51.3234,
            46.1284,
            46.8178,
            45.4238,
            42.8229,
            39.2844,
            37.1034,
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
    "LTQueue": {"color": "red", "marker": "s"},
    "FastQueue": {"color": "green", "marker": "^"},
    "SlotqueueV2a": {"color": "purple", "marker": "d", "linestyle": "--"},
    "SlotqueueV2b": {"color": "orange", "marker": "x", "linestyle": "-."},
    "SlotqueueV2c": {"color": "brown", "marker": "*", "linestyle": ":"},
    "SlotqueueV2bc": {"color": "magenta", "marker": "+", "linestyle": "--"},
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
            label=f"{queue_name}{'*' if queue_name == 'SlotqueueV2a' else ''}",
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
    "Note: SlotqueueV2a is marked with an asterisk (*) in the legend to indicate it is experimental."
)
