import matplotlib.pyplot as plt
import os

# Create directory if it doesn't exist
os.makedirs("./by-nodes", exist_ok=True)

# Data from the measurements
nodes = [2, 4, 8, 16]
patterns = ["all-to-all", "root", "scatter"]

# Performance data (in cycles or time units)
sopnop_data = {
    "all-to-all": [4e7, 7.25e7, 1.911e8, 3.9e8],
    "root": [
        9.46e7,
        2.82e8,
        7.39e8,
        2.47e9,
    ],
    "scatter": [4e7, 8.89e7, 1.95e8, 2.32e8],
}

sq_data = {
    "all-to-all": [4.22e7, 5.33e8, 2.52e8, 2.005e8],
    "root": [3.36e8, 9.23e8, 2.00e9, 7.31e9],
    "scatter": [4.75e8, 5.41e8, 2.43e8, 2.53e8],
}

# Colors and styling
sopnop_color = "#2E86C1"
sq_color = "#E74C3C"

# Create separate plots for each pattern
for pattern in patterns:
    fig, ax = plt.subplots(1, 1, figsize=(15, 6))
    fig.suptitle(
        f"{pattern.upper()} Communication Pattern\n(100,000 messages, 1024 buffer size)",
        fontsize=16,
        fontweight="bold",
    )

    ax.plot(
        nodes,
        sopnop_data[pattern],
        marker="o",
        linewidth=3,
        markersize=10,
        label="AMQueue",
        color=sopnop_color,
    )
    ax.plot(
        nodes,
        sq_data[pattern],
        marker="s",
        linewidth=3,
        markersize=10,
        label="Unbounded Slotqueue",
        color=sq_color,
    )

    ax.set_xlabel("Number of Nodes", fontsize=12)
    ax.set_ylabel("Latency (us)", fontsize=12)
    ax.set_yscale("log")
    ax.set_xscale("log")
    ax.minorticks_off()
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=12)
    ax.set_xticks(nodes, [str(int(node)) for node in nodes], fontsize=12)

    # Save the plot
    filename = f"./by-nodes/{pattern}.png"
    plt.savefig(filename, dpi=300, bbox_inches="tight")
    print(f"Saved {filename}")
