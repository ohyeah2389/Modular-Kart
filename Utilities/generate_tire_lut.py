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
    slope_x = params['SLOPE_X']
    m_clamp = params['M_CLAMP']
    
    exp_term = 2 / (1 + np.exp(-x * (slope_1/10000))) - 1
    main_term = (20000 * exp_term) / (slope_1 * x)
    
    result = (ref_m * x_mult) + (adhesion/x) - ((slope_0 * slope_x)/10000) * x * main_term
    return min(result, m_clamp)


def load_parameters(config_file):
    """Load parameters from TOML configuration file"""
    try:
        with open(config_file, 'rb') as f:
            config = tomli.load(f)
        return config['front_tire'], config['rear_tire'], config['base_path'], config['ranges']
    except FileNotFoundError:
        print(f"Error: Configuration file '{config_file}' not found.")
        print("Please ensure tire_parameters.toml exists in the same directory as this script.")
        exit(1)
    except Exception as e:
        print(f"Error reading configuration file: {str(e)}")
        exit(1)


def write_lut_file(filename, values, outputs, params):
    """Write the lookup table to a file"""
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    
    with open(filename, 'w') as f:
        
        # Write data points
        for x, y in zip(values, outputs):
            f.write(f"{int(x)}\t|\t{y:.3f}\n")
        
        # Write timestamp and header
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        f.write(f"\n;Generated on {timestamp} from the following parameters:\n")
        
        # Write parameters as comments
        f.write(f"\n;REF_M\t{params['REF_M']}")
        f.write(f"\n;SLOPE_0\t{params['SLOPE_0']}")
        f.write(f"\n;SLOPE_1\t{params['SLOPE_1']}")
        f.write(f"\n;ADHESION\t{params['ADHESION']}")
        f.write(f"\n;X_MULT\t{params['X_MULT']}")
        f.write(f"\n;SLOPE_X\t{params['SLOPE_X']}")
        f.write(f"\n;M_CLAMP\t{params['M_CLAMP']}")


def generate_all_luts(config_file='tire_parameters.toml'):
    """Generate all four LUT files for front and rear tires"""
    print("Tire LUT Generator")
    
    # Load parameters from TOML file
    front_params, rear_params, base_path, ranges = load_parameters(config_file)
    print("\nLoaded parameters from", config_file)
    
    # Get input values
    x_values = generate_input_values(ranges)
    
    # Generate all four files
    tire_configs = [
        ("front_lat", f"{base_path['path']}/{base_path['front_tire_lat_file']}", front_params, True),
        ("front_long", f"{base_path['path']}/{base_path['front_tire_long_file']}", front_params, False),
        ("rear_lat", f"{base_path['path']}/{base_path['rear_tire_lat_file']}", rear_params, True),
        ("rear_long", f"{base_path['path']}/{base_path['rear_tire_long_file']}", rear_params, False)
    ]
    
    for name, filename, params, is_lateral in tire_configs:
        # Calculate outputs
        if is_lateral:
            outputs = [calculate_lateral(x, params) for x in x_values]
        else:
            outputs = [calculate_longitudinal(x, params) for x in x_values]
        
        # Write the file
        write_lut_file(filename, x_values, outputs, params)
        print(f"\nGenerated {name} LUT: {filename}")


def main():
    generate_all_luts()
    print("\nAll LUT files generated successfully!")


if __name__ == "__main__":
    main() 