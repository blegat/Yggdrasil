using BinaryBuilder

name = "Pumpkin"
version = v"0.5.0"

sources = [
    GitSource("https://github.com/ConSol-Lab/Pumpkin.git",
              "b2574d46f8d5b64665f289e7f94e542994a73750"),
]

# Besides the solver binary, install the MiniZinc solver configurations and
# their FlatZinc libraries, so that `minizinc --solver pumpkin` works against
# the artifact.  `pumpkin.msc` uses Pumpkin's native global constraints;
# `pumpkin-proof.msc` decomposes everything but `cumulative` into linear
# constraints, which is what Pumpkin needs in order to log a DRCP proof.
script = "PUMPKIN_VERSION=$(version)\n" * raw"""
cd ${WORKSPACE}/srcdir/Pumpkin

# The checkers are only used by upstream's integration tests.  Disabling them
# avoids building target executables which Cargo would try to run on the host.
export NO_CHECKERS=true
cargo build --release --locked --package pumpkin-solver --bin pumpkin-solver

install -Dvm 755 \
    "target/${rust_target}/release/pumpkin-solver${exeext}" \
    "${bindir}/pumpkin-solver${exeext}"

install -Dvm 644 -t "${prefix}/share/minizinc/pumpkin" minizinc/lib/*.mzn
install -Dvm 644 -t "${prefix}/share/minizinc/pumpkin-proof" \
    minizinc/lib-for-proofs/*.mzn

# Paths inside a `.msc` are resolved relative to the file itself, so rewriting
# upstream's development paths to relative ones keeps the artifact
# relocatable.  Upstream also stamps both files with `"version": "0.1"`;
# replace it with the version actually being built.
install_msc() {
    sed -e "s|\"version\": \"0.1\"|\"version\": \"${PUMPKIN_VERSION}\"|" \
        -e "s|\"executable\": \"../target/release/pumpkin-solver\"|\"executable\": \"../../../bin/pumpkin-solver${exeext}\"|" \
        -e "s|\"mznlib\": \"$2\"|\"mznlib\": \"../$3\"|" \
        "minizinc/$1.msc" \
        > "${prefix}/share/minizinc/solvers/$3.msc"
}
mkdir -p "${prefix}/share/minizinc/solvers"
install_msc pumpkin './lib' pumpkin
install_msc pumpkin-for-proofs './lib-for-proofs/' pumpkin-proof

install_license LICENSE-MIT LICENSE-APACHE
"""

platforms = supported_platforms()

products = [
    ExecutableProduct("pumpkin-solver", :pumpkin_solver),
    FileProduct("share/minizinc/solvers/pumpkin.msc", :pumpkin_msc),
    FileProduct("share/minizinc/solvers/pumpkin-proof.msc", :pumpkin_proof_msc),
]

dependencies = Dependency[]

build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               compilers=[:c, :rust], julia_compat="1.6")
