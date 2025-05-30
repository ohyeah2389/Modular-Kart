import numpy as np
import os
import tomli  # for reading TOML files
from datetime import datetime


def generate_input_values(ranges):
    """Generate the sequence of input values according to the specified increments"""
    values = []
    
    # 0 to 400 in steps of 20
    values.extend(np.arange(0, ranges['by_twentys'] + 1, 20))
    
    # 400 to 3000 in steps of 100
    values.extend(np.arange(ranges['by_twentys'], ranges['by_hundreds'] + 1, 100))
    
    # 3000 to 40000 in steps of 500
    values.extend(np.arange(ranges['by_hundreds'], ranges['by_fivehundreds'] + 1, 500))
    
    # Remove duplicates that might occur at transition points
    return sorted(list(set(values)))


def calculate_lateral(x, params):
    """Calculate lateral friction value based on input parameters"""
    x = max(0.000001, x)  # Prevent division by zero
    
    ref_m = params['REF_M']
    adhesion = params['ADHESION']
    slope_0 = params['SLOPE_0']
    slope_1 = params['SLOPE_1']
    m_clamp = params['M_CLAMP']
    
    exp_term = 2 / (1 + np.exp(-x * (slope_1/10000))) - 1
    main_term = (20000 * exp_term) / (slope_1 * x)
    
    result = ref_m + (adhesion/x) - (slope_0/10000) * x * main_term
    return min(result, m_clamp)


def calculate_longitudinal(x, params):
    """Calculate longitudinal friction value based on input parameters"""
    x = max(0.000001, x)  # Prevent division by zero
    
    ref_m = params['REF_M']
    adhesion = params['ADHESION']
    slope_0 = params['SLOPE_0']
    slope_1 = params['SLOPE_1']
    x_mult = params['X_MULT']
    slope_0_x = params['SLOPE_0_X']
    slope_1_x = params['SLOPE_1_X']
    m_clamp = params['M_CLAMP']
    
    exp_term = 2 / (1 + np.exp(-x * ((slope_1 * slope_1_x)/10000))) - 1
    main_term = (20000 * exp_term) / ((slope_1 * slope_1_x) * x)
    
    result = (ref_m * x_mult) + (adhesion/x) - ((slope_0 * slope_0_x)/10000) * x * main_term
    return min(result, m_clamp)


def load_parameters(config_file):
    """Load parameters from TOML configuration file"""
    try:
        with open(config_file, 'rb') as f:
            config = tomli.load(f)
        # Return the entire config dictionary
        return config
    except FileNotFoundError:
        print(f"Error: Configuration file '{config_file}' not found.")
        print(f"Please ensure {config_file} exists in the same directory as this script.")
        exit(1)
    except Exception as e:
        print(f"Error reading configuration file: {str(e)}")
        exit(1)


def write_lut_file(filename, values, outputs, params):
    """Write the lookup table to a file"""
    # Ensure the base directory exists
    output_dir = os.path.dirname(filename)
    if output_dir: # Check if dirname returned a non-empty string
        os.makedirs(output_dir, exist_ok=True)
    else:
        # Handle case where filename is in the current directory
        print(f"Warning: Outputting file '{filename}' to the current directory.")

    with open(filename, 'w') as f:

        # Write data points
        for x, y in zip(values, outputs):
            f.write(f"{int(x)}\t|\t{y:.3f}\n")

        # Write timestamp and header
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        f.write(f"\n;Generated on {timestamp} from the following parameters:\n")

        # Write parameters as comments
        f.write(f"\n;REF_M\t{params.get('REF_M', 'N/A')}") # Use .get for safety
        f.write(f"\n;SLOPE_0\t{params.get('SLOPE_0', 'N/A')}")
        f.write(f"\n;SLOPE_1\t{params.get('SLOPE_1', 'N/A')}")
        f.write(f"\n;ADHESION\t{params.get('ADHESION', 'N/A')}")
        f.write(f"\n;X_MULT\t{params.get('X_MULT', 'N/A')}")
        f.write(f"\n;SLOPE_0_X\t{params.get('SLOPE_0_X', 'N/A')}")
        f.write(f"\n;SLOPE_1_X\t{params.get('SLOPE_1_X', 'N/A')}")
        f.write(f"\n;M_CLAMP\t{params.get('M_CLAMP', 'N/A')}")


def generate_all_luts(config_file='tire_parameters.toml'):
    """Generate all LUT files based on configurations in the TOML file"""
    print("Tire LUT Generator")

    # Load the entire configuration
    config = load_parameters(config_file)
    print(f"\nLoaded configuration from {config_file}")

    # Extract base_path and ranges, handle potential KeyError
    try:
        base_path = config['base_path']
        ranges = config['ranges']
        base_dir = base_path.get('path', '.') # Default to current dir if 'path' is missing
    except KeyError as e:
        print(f"Error: Missing required section in {config_file}: {e}")
        exit(1)

    # Get input values
    x_values = generate_input_values(ranges)

    # Dynamically build the list of tire configurations to generate
    tire_configs_to_generate = []
    for section_name, params in config.items():
        # Identify tire parameter sections (e.g., front_tire_0, rear_tire_1)
        if section_name.startswith("front_tire_") or section_name.startswith("rear_tire_"):
            print(f"Found tire configuration: {section_name}")

            # Construct expected keys for LUT filenames in base_path
            lat_file_key = f"{section_name}_lat_file"
            long_file_key = f"{section_name}_long_file"

            # Check if filenames are defined in base_path
            if lat_file_key not in base_path:
                print(f"Warning: Lateral LUT filename key '{lat_file_key}' not found in [base_path] for {section_name}. Skipping lateral LUT.")
            else:
                lat_filename = os.path.join(base_dir, base_path[lat_file_key])
                tire_configs_to_generate.append((f"{section_name}_lat", lat_filename, params, True))

            if long_file_key not in base_path:
                print(f"Warning: Longitudinal LUT filename key '{long_file_key}' not found in [base_path] for {section_name}. Skipping longitudinal LUT.")
            else:
                long_filename = os.path.join(base_dir, base_path[long_file_key])
                tire_configs_to_generate.append((f"{section_name}_long", long_filename, params, False))

    if not tire_configs_to_generate:
        print("\nError: No tire configurations found or no corresponding LUT filenames defined in [base_path].")
        exit(1)

    # Generate all found LUT files
    for name, filename, params, is_lateral in tire_configs_to_generate:
        # Calculate outputs
        try:
            if is_lateral:
                outputs = [calculate_lateral(x, params) for x in x_values]
            else:
                outputs = [calculate_longitudinal(x, params) for x in x_values]
        except KeyError as e:
             print(f"\nError: Missing parameter {e} in section '{name.split('_')[0]}_{name.split('_')[1]}'. Skipping {name} LUT.")
             continue # Skip to the next configuration

        # Write the file
        write_lut_file(filename, x_values, outputs, params)
        print(f"\nGenerated {name} LUT: {filename}")


def main():
    generate_all_luts()
    print("\nAll LUT files generated successfully!")


if __name__ == "__main__":
    main() 