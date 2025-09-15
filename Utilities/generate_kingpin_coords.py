#!/usr/bin/env python3
"""
This script calculates kingpin joint coordinates based on input KPI and caster angles.
Usage:
    python generate_kingpin_coords.py --kpi 15 --caster -13.5
    python generate_kingpin_coords.py --kpi 12 --caster 5 --vertical-sep 0.066
    python generate_kingpin_coords.py --kpi 10 --caster 0 --center 0.1579,0.0,0.0
"""

import argparse
import math
import sys
from typing import Tuple


def calculate_kingpin_coordinates(
    kpi_degrees: float,
    caster_degrees: float,
    vertical_separation: float = 0.066,
    center_position: Tuple[float, float, float] = (0.1579, 0.0, 0.0),
) -> Tuple[Tuple[float, float, float], Tuple[float, float, float]]:
    """
    Calculate kingpin joint coordinates for given KPI and caster angles.

    Args:
        kpi_degrees: King Pin Inclination in degrees (positive = inward lean at top)
        caster_degrees: Caster angle in degrees (positive = forward lean at top)
        vertical_separation: Vertical distance between joints in meters
        center_position: Center position as (lateral, vertical, longitudinal) in meters

    Returns:
        Tuple of (top_joint_pos, bottom_joint_pos) as (lateral, vertical, longitudinal)
    """
    # Convert angles to radians
    kpi_rad = math.radians(kpi_degrees)
    caster_rad = math.radians(caster_degrees)

    # Calculate offsets from center
    half_vertical = vertical_separation / 2

    # Calculate lateral offset for KPI (viewed from front)
    lateral_offset = math.tan(kpi_rad) * half_vertical

    # Calculate longitudinal offset for caster (viewed from side)
    # Positive caster = top joint forward of bottom joint
    longitudinal_offset = math.tan(caster_rad) * half_vertical

    # Calculate joint positions
    center_lat, center_vert, center_long = center_position

    # Top joint (higher vertical position)
    top_joint = (
        center_lat + lateral_offset,
        center_vert + half_vertical,
        center_long + longitudinal_offset,
    )

    # Bottom joint (lower vertical position)
    bottom_joint = (
        center_lat - lateral_offset,
        center_vert - half_vertical,
        center_long - longitudinal_offset,
    )

    return top_joint, bottom_joint


def format_coordinates(coords: Tuple[float, float, float], precision: int = 5) -> str:
    """Format coordinates for AC suspension file."""
    return f"{coords[0]:.{precision}f}, {coords[1]:.{precision}f}, {coords[2]:.{precision}f}"


def verify_angles(
    top_joint: Tuple[float, float, float], bottom_joint: Tuple[float, float, float]
) -> Tuple[float, float]:
    """
    Verify the calculated angles from joint positions.

    Returns:
        Tuple of (actual_kpi, actual_caster) in degrees
    """
    lat_diff = top_joint[0] - bottom_joint[0]
    vert_diff = top_joint[1] - bottom_joint[1]
    long_diff = top_joint[2] - bottom_joint[2]

    actual_kpi = math.degrees(math.atan(lat_diff / vert_diff))
    actual_caster = math.degrees(math.atan(long_diff / vert_diff))

    return actual_kpi, actual_caster


def parse_center_position(center_str: str) -> Tuple[float, float, float]:
    """Parse center position from command line string."""
    try:
        coords = [float(x.strip()) for x in center_str.split(",")]
        if len(coords) != 3:
            raise ValueError("Center position must have exactly 3 coordinates")
        return tuple(coords)
    except ValueError as e:
        raise argparse.ArgumentTypeError(f"Invalid center position format: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate kingpin coordinates for given KPI and caster angles",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --kpi 15 --caster -13.5
  %(prog)s --kpi 12 --caster 5 --vertical-sep 0.066
  %(prog)s --kpi 10 --caster 0 --center 0.16,0.0,0.0
        """,
    )

    parser.add_argument(
        "--kpi",
        type=float,
        required=True,
        help="King Pin Inclination in degrees (positive = inward lean at top)",
    )

    parser.add_argument(
        "--caster",
        type=float,
        required=True,
        help="Caster angle in degrees (positive = forward lean at top)",
    )

    parser.add_argument(
        "--vertical-sep",
        type=float,
        default=0.066,
        help="Vertical separation between joints in meters (default: 0.066)",
    )

    parser.add_argument(
        "--center",
        type=parse_center_position,
        default=(0.1579, 0.0, 0.0),
        help='Center position as "lat,vert,long" in meters (default: 0.1579, 0.0, 0.0)',
    )

    parser.add_argument(
        "--precision",
        type=int,
        default=6,
        help="Decimal precision for output coordinates (default: 6)",
    )

    parser.add_argument(
        "--verify", action="store_true", help="Verify the calculated angles"
    )

    args = parser.parse_args()

    try:
        # Calculate coordinates
        top_joint, bottom_joint = calculate_kingpin_coordinates(
            args.kpi, args.caster, args.vertical_sep, args.center
        )

        # Format output
        top_coords = format_coordinates(top_joint, args.precision)
        bottom_coords = format_coordinates(bottom_joint, args.precision)

        print(f"Kingpin Coordinates for KPI={args.kpi}° and Caster={args.caster}°")
        print(f"Center position: {format_coordinates(args.center, args.precision)}")
        print(f"Vertical separation: {args.vertical_sep} m")
        print()
        print("Suspension file format:")
        print(f"J0_POS={top_coords}")
        print(f"J1_POS={bottom_coords}")

        if args.verify:
            actual_kpi, actual_caster = verify_angles(top_joint, bottom_joint)
            print()
            print("Verification:")
            print(f"Actual KPI: {actual_kpi:.3f}°")
            print(f"Actual Caster: {actual_caster:.3f}°")
            print(f"KPI error: {abs(actual_kpi - args.kpi):.6f}°")
            print(f"Caster error: {abs(actual_caster - args.caster):.6f}°")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
