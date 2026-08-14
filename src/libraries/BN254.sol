// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Types } from "./Types.sol";

/// @title BN254
/// @notice BN254 (alt_bn128) curve operations for BLS signature verification
/// @dev Uses EVM precompiles at addresses 0x06, 0x07, and 0x08 for efficient operations.
///      SECURITY CRITICAL: do not modify this library casually to chase gas or compile-time wins.
///      Any change must preserve exact cryptographic semantics, be reviewed against the original
///      source/provenance in git history, and receive dedicated cryptography-focused review.
///      This header is intentionally conservative and does not claim a standalone audit unless
///      that provenance is explicitly documented elsewhere.
library BN254 {
    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice The prime field modulus for BN254
    uint256 internal constant P_MOD =
        21_888_242_871_839_275_222_246_405_745_257_275_088_696_311_157_297_823_662_689_037_894_645_226_208_583;

    /// @notice The group order for BN254
    uint256 internal constant R_MOD =
        21_888_242_871_839_275_222_246_405_745_257_275_088_548_364_400_416_034_343_698_204_186_575_808_495_617;

    /// @notice G1 generator x coordinate
    uint256 internal constant G1_X = 1;

    /// @notice G1 generator y coordinate
    uint256 internal constant G1_Y = 2;

    /// @notice G2 coordinates use EIP-197 order [imaginary, real].
    /// @dev The field element is x = x[1] + x[0] * i (and likewise for y).
    uint256 internal constant G2_X0 =
        11_559_732_032_986_387_107_991_004_021_392_285_783_925_812_861_821_192_530_917_403_151_452_391_805_634;
    uint256 internal constant G2_X1 =
        10_857_046_999_023_057_135_944_570_762_232_829_481_370_756_359_578_518_086_990_519_993_285_655_852_781;

    /// @notice G2 generator y coordinates (y = y0 * i + y1)
    uint256 internal constant G2_Y0 =
        4_082_367_875_863_433_681_332_203_403_145_435_568_316_851_327_593_401_208_105_741_076_214_120_093_531;
    uint256 internal constant G2_Y1 =
        8_495_653_923_123_431_417_604_973_247_489_272_438_418_190_587_263_600_148_770_280_649_306_958_101_930;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════════

    error InvalidG1Point();
    error InvalidG2Point();
    error PairingFailed();
    error HashToPointFailed();
    error DegenerateBlsInput();

    // ═══════════════════════════════════════════════════════════════════════════
    // POINT VALIDATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Check if a G1 point is valid (on the curve)
    /// @param p The G1 point to validate
    /// @return True if valid
    function isValidG1(Types.BN254G1Point memory p) internal pure returns (bool) {
        if (p.x == 0 && p.y == 0) {
            return true; // Point at infinity is valid
        }
        if (p.x >= P_MOD || p.y >= P_MOD) {
            return false;
        }
        // Check y^2 = x^3 + 3 (mod p)
        uint256 lhs = mulmod(p.y, p.y, P_MOD);
        uint256 rhs = addmod(mulmod(mulmod(p.x, p.x, P_MOD), p.x, P_MOD), 3, P_MOD);
        return lhs == rhs;
    }

    /// @notice Check if a G2 point is valid
    /// @dev Full validation would require extension field arithmetic, so we just check bounds
    /// @param p The G2 point to validate
    /// @return True if bounds are valid
    function isValidG2(Types.BN254G2Point memory p) internal pure returns (bool) {
        return p.x[0] < P_MOD && p.x[1] < P_MOD && p.y[0] < P_MOD && p.y[1] < P_MOD;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // G1 OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Add two G1 points using precompile 0x06
    /// @param p1 First point
    /// @param p2 Second point
    /// @return r The sum p1 + p2
    function addG1(
        Types.BN254G1Point memory p1,
        Types.BN254G1Point memory p2
    )
        internal
        view
        returns (Types.BN254G1Point memory r)
    {
        uint256[4] memory input;
        input[0] = p1.x;
        input[1] = p1.y;
        input[2] = p2.x;
        input[3] = p2.y;

        bool success;
        // Assembly is required to call the bn256Add precompile at address 0x06
        // Input: 4 uint256 values (2 G1 points) = 0x80 bytes
        // Output: 2 uint256 values (1 G1 point) = 0x40 bytes
        // sub(gas(), 2000) reserves gas for post-call operations
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0x80, r, 0x40)
        }
        if (!success) revert InvalidG1Point();
    }

    /// @notice Scalar multiplication on G1 using precompile 0x07
    /// @param p The point to multiply
    /// @param s The scalar
    /// @return r The product s * p
    function scalarMulG1(Types.BN254G1Point memory p, uint256 s) internal view returns (Types.BN254G1Point memory r) {
        uint256[3] memory input;
        input[0] = p.x;
        input[1] = p.y;
        input[2] = s;

        bool success;
        // Assembly is required to call the bn256ScalarMul precompile at address 0x07
        // Input: 3 uint256 values (1 G1 point + scalar) = 0x60 bytes
        // Output: 2 uint256 values (1 G1 point) = 0x40 bytes
        // sub(gas(), 2000) reserves gas for post-call operations
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x60, r, 0x40)
        }
        if (!success) revert InvalidG1Point();
    }

    /// @notice Negate a G1 point (reflect over x-axis)
    /// @param p The point to negate
    /// @return The negated point
    function negateG1(Types.BN254G1Point memory p) internal pure returns (Types.BN254G1Point memory) {
        if (p.x == 0 && p.y == 0) {
            return p; // Point at infinity
        }
        return Types.BN254G1Point(p.x, P_MOD - (p.y % P_MOD));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // G2 OPERATIONS (Extension Field Arithmetic)
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Add two G2 points using extension field arithmetic
    /// @dev G2 is defined over Fp2 = Fp[i]/(i^2 + 1), so we need complex addition
    /// @param p1 First G2 point
    /// @param p2 Second G2 point
    /// @return r The sum p1 + p2
    function addG2(
        Types.BN254G2Point memory p1,
        Types.BN254G2Point memory p2
    )
        internal
        pure
        returns (Types.BN254G2Point memory r)
    {
        // Handle point at infinity cases
        if (isG2Infinity(p1)) return p2;
        if (isG2Infinity(p2)) return p1;

        // Check if points are the same (need to double)
        if (p1.x[0] == p2.x[0] && p1.x[1] == p2.x[1] && p1.y[0] == p2.y[0] && p1.y[1] == p2.y[1]) {
            return doubleG2(p1);
        }

        // Check if points are inverses (result is infinity)
        // -P = (x, -y) in G2
        (uint256 negY0, uint256 negY1) = fp2Negate(p2.y[0], p2.y[1]);
        if (p1.x[0] == p2.x[0] && p1.x[1] == p2.x[1] && p1.y[0] == negY0 && p1.y[1] == negY1) {
            return Types.BN254G2Point([uint256(0), uint256(0)], [uint256(0), uint256(0)]);
        }

        // Standard point addition: lambda = (y2 - y1) / (x2 - x1)
        // x3 = lambda^2 - x1 - x2
        // y3 = lambda * (x1 - x3) - y1

        // Compute y2 - y1 in Fp2
        (uint256 dy0, uint256 dy1) = fp2Sub(p2.y[0], p2.y[1], p1.y[0], p1.y[1]);

        // Compute x2 - x1 in Fp2
        (uint256 dx0, uint256 dx1) = fp2Sub(p2.x[0], p2.x[1], p1.x[0], p1.x[1]);

        // Compute lambda = dy / dx in Fp2
        (uint256 lambda0, uint256 lambda1) = fp2Div(dy0, dy1, dx0, dx1);

        // Compute lambda^2 in Fp2
        (uint256 lambda2_0, uint256 lambda2_1) = fp2Mul(lambda0, lambda1, lambda0, lambda1);

        // Compute x3 = lambda^2 - x1 - x2 in Fp2
        (uint256 x3_0, uint256 x3_1) = fp2Sub(lambda2_0, lambda2_1, p1.x[0], p1.x[1]);
        (x3_0, x3_1) = fp2Sub(x3_0, x3_1, p2.x[0], p2.x[1]);

        // Compute y3 = lambda * (x1 - x3) - y1 in Fp2
        (uint256 x1_x3_0, uint256 x1_x3_1) = fp2Sub(p1.x[0], p1.x[1], x3_0, x3_1);
        (uint256 y3_0, uint256 y3_1) = fp2Mul(lambda0, lambda1, x1_x3_0, x1_x3_1);
        (y3_0, y3_1) = fp2Sub(y3_0, y3_1, p1.y[0], p1.y[1]);

        r.x[0] = x3_0;
        r.x[1] = x3_1;
        r.y[0] = y3_0;
        r.y[1] = y3_1;
    }

    /// @notice Double a G2 point
    /// @param p The G2 point to double
    /// @return r The doubled point 2*p
    function doubleG2(Types.BN254G2Point memory p) internal pure returns (Types.BN254G2Point memory r) {
        if (isG2Infinity(p)) return p;

        // Check if y = 0 (tangent is vertical, result is infinity)
        if (p.y[0] == 0 && p.y[1] == 0) {
            return Types.BN254G2Point([uint256(0), uint256(0)], [uint256(0), uint256(0)]);
        }

        // Point doubling: lambda = 3x^2 / 2y (for curve y^2 = x^3 + b)
        // Note: For BN254 G2, the curve is y^2 = x^3 + b' where b' is in Fp2

        // Compute 3x^2 in Fp2
        (uint256 x2_0, uint256 x2_1) = fp2Mul(p.x[0], p.x[1], p.x[0], p.x[1]);
        (uint256 three_x2_0, uint256 three_x2_1) = fp2MulScalar(x2_0, x2_1, 3);

        // Compute 2y in Fp2
        (uint256 two_y0, uint256 two_y1) = fp2MulScalar(p.y[0], p.y[1], 2);

        // Compute lambda = 3x^2 / 2y in Fp2
        (uint256 lambda0, uint256 lambda1) = fp2Div(three_x2_0, three_x2_1, two_y0, two_y1);

        // Compute lambda^2 in Fp2
        (uint256 lambda2_0, uint256 lambda2_1) = fp2Mul(lambda0, lambda1, lambda0, lambda1);

        // Compute x3 = lambda^2 - 2x in Fp2
        (uint256 two_x0, uint256 two_x1) = fp2MulScalar(p.x[0], p.x[1], 2);
        (uint256 x3_0, uint256 x3_1) = fp2Sub(lambda2_0, lambda2_1, two_x0, two_x1);

        // Compute y3 = lambda * (x - x3) - y in Fp2
        (uint256 x_x3_0, uint256 x_x3_1) = fp2Sub(p.x[0], p.x[1], x3_0, x3_1);
        (uint256 y3_0, uint256 y3_1) = fp2Mul(lambda0, lambda1, x_x3_0, x_x3_1);
        (y3_0, y3_1) = fp2Sub(y3_0, y3_1, p.y[0], p.y[1]);

        r.x[0] = x3_0;
        r.x[1] = x3_1;
        r.y[0] = y3_0;
        r.y[1] = y3_1;
    }

    /// @notice Check if a G2 point is the point at infinity
    function isG2Infinity(Types.BN254G2Point memory p) internal pure returns (bool) {
        return p.x[0] == 0 && p.x[1] == 0 && p.y[0] == 0 && p.y[1] == 0;
    }

    /// @notice Check if a G1 point is the point at infinity (encoded as (0, 0))
    function isG1Infinity(Types.BN254G1Point memory p) internal pure returns (bool) {
        return p.x == 0 && p.y == 0;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FP2 ARITHMETIC (Extension Field: Fp2 = Fp[i]/(i^2 + 1))
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Add two EIP-197 Fp2 elements stored as [imaginary, real].
    function fp2Add(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (uint256 c0, uint256 c1) {
        c0 = addmod(a0, b0, P_MOD);
        c1 = addmod(a1, b1, P_MOD);
    }

    /// @notice Subtract two EIP-197 Fp2 elements stored as [imaginary, real].
    function fp2Sub(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (uint256 c0, uint256 c1) {
        c0 = addmod(a0, P_MOD - (b0 % P_MOD), P_MOD);
        c1 = addmod(a1, P_MOD - (b1 % P_MOD), P_MOD);
    }

    /// @notice Multiply two EIP-197 Fp2 elements stored as [imaginary, real].
    /// @dev For a = a1 + a0*i and b = b1 + b0*i, i^2 = -1.
    function fp2Mul(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (uint256 c0, uint256 c1) {
        uint256 arbr = mulmod(a1, b1, P_MOD);
        uint256 aibi = mulmod(a0, b0, P_MOD);
        uint256 arbi = mulmod(a1, b0, P_MOD);
        uint256 aibr = mulmod(a0, b1, P_MOD);

        c0 = addmod(arbi, aibr, P_MOD);
        c1 = addmod(arbr, P_MOD - aibi, P_MOD);
    }

    /// @notice Multiply Fp2 element by a scalar
    function fp2MulScalar(uint256 a0, uint256 a1, uint256 s) internal pure returns (uint256 c0, uint256 c1) {
        c0 = mulmod(a0, s, P_MOD);
        c1 = mulmod(a1, s, P_MOD);
    }

    /// @notice Negate an EIP-197 Fp2 element stored as [imaginary, real].
    function fp2Negate(uint256 a0, uint256 a1) internal pure returns (uint256 c0, uint256 c1) {
        c0 = a0 == 0 ? 0 : P_MOD - (a0 % P_MOD);
        c1 = a1 == 0 ? 0 : P_MOD - (a1 % P_MOD);
    }

    /// @notice Compute the inverse of an EIP-197 Fp2 element.
    /// @dev For a = a1 + a0*i, a^(-1) = (a1 - a0*i) / (a1^2 + a0^2).
    function fp2Inverse(uint256 a0, uint256 a1) internal pure returns (uint256 c0, uint256 c1) {
        uint256 ai_sq = mulmod(a0, a0, P_MOD);
        uint256 ar_sq = mulmod(a1, a1, P_MOD);
        uint256 norm = addmod(ai_sq, ar_sq, P_MOD);

        uint256 normInv = expMod(norm, P_MOD - 2, P_MOD);

        c0 = mulmod(P_MOD - (a0 % P_MOD), normInv, P_MOD);
        c1 = mulmod(a1, normInv, P_MOD);
    }

    /// @notice Divide two Fp2 elements: a / b = a * b^(-1)
    function fp2Div(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (uint256 c0, uint256 c1) {
        (uint256 bInv0, uint256 bInv1) = fp2Inverse(b0, b1);
        return fp2Mul(a0, a1, bInv0, bInv1);
    }

    /// @notice Compare two G2 points for equality
    function g2Eq(Types.BN254G2Point memory p1, Types.BN254G2Point memory p2) internal pure returns (bool) {
        return p1.x[0] == p2.x[0] && p1.x[1] == p2.x[1] && p1.y[0] == p2.y[0] && p1.y[1] == p2.y[1];
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PAIRING
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Check a pairing equation using precompile 0x08
    /// @dev Verifies e(p1[0], p2[0]) * e(p1[1], p2[1]) * ... = 1
    /// @param p1 Array of G1 points
    /// @param p2 Array of G2 points
    /// @return True if the pairing equation holds
    function pairing(Types.BN254G1Point[] memory p1, Types.BN254G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length, "BN254: pairing length mismatch");
        uint256 elements = p1.length;
        uint256 inputSize = elements * 6;
        uint256[] memory input = new uint256[](inputSize);

        for (uint256 i = 0; i < elements; i++) {
            input[i * 6 + 0] = p1[i].x;
            input[i * 6 + 1] = p1[i].y;
            // G2 point encoding per EIP-197:
            // x = x[0] * i + x[1], y = y[0] * i + y[1]
            // Point (a0 + i*a1, b0 + i*b1) is encoded as [a1, a0, b1, b0]
            // So x[0]=a1 (imag), x[1]=a0 (real), encode as [x[0], x[1], y[0], y[1]]
            input[i * 6 + 2] = p2[i].x[0];
            input[i * 6 + 3] = p2[i].x[1];
            input[i * 6 + 4] = p2[i].y[0];
            input[i * 6 + 5] = p2[i].y[1];
        }

        uint256[1] memory result;
        bool success;
        // Assembly is required to call the bn256Pairing precompile at address 0x08
        // Input: Variable length array of (G1, G2) point pairs
        //        add(input, 0x20) skips the array length prefix
        //        mul(inputSize, 0x20) calculates total input bytes
        // Output: Single uint256 (1 = pairing valid, 0 = invalid) = 0x20 bytes
        // sub(gas(), 2000) reserves gas for post-call operations
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), result, 0x20)
        }
        if (!success) revert PairingFailed();
        return result[0] == 1;
    }

    /// @notice Verify a single pairing e(a, b) == e(c, d)
    /// @dev Uses the fact that e(a,b) * e(-c,d) = 1 iff e(a,b) = e(c,d)
    function pairingCheck(
        Types.BN254G1Point memory a,
        Types.BN254G2Point memory b,
        Types.BN254G1Point memory c,
        Types.BN254G2Point memory d
    )
        internal
        view
        returns (bool)
    {
        Types.BN254G1Point[] memory p1 = new Types.BN254G1Point[](2);
        Types.BN254G2Point[] memory p2 = new Types.BN254G2Point[](2);
        p1[0] = a;
        p1[1] = negateG1(c);
        p2[0] = b;
        p2[1] = d;
        return pairing(p1, p2);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BLS SIGNATURE VERIFICATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Hash a message to a G1 point using try-and-increment
    /// @dev This is a simple hash-to-curve, not a constant-time one
    /// @param message The message to hash
    /// @return The G1 point
    function hashToG1(bytes memory message) internal pure returns (Types.BN254G1Point memory) {
        uint256 h = uint256(keccak256(message)) % P_MOD;
        uint256 x = h;

        // Try-and-increment: find smallest x such that x^3 + 3 is a quadratic residue
        for (uint256 i = 0; i < 256; i++) {
            uint256 y2 = addmod(mulmod(mulmod(x, x, P_MOD), x, P_MOD), 3, P_MOD);
            uint256 y = sqrtMod(y2);
            if (mulmod(y, y, P_MOD) == y2) {
                return Types.BN254G1Point(x, y);
            }
            x = addmod(x, 1, P_MOD);
        }
        revert HashToPointFailed();
    }

    /// @notice Verify a BLS signature
    /// @dev Checks e(signature, G2) = e(H(message), pubkey)
    /// @param message The signed message
    /// @param signature The BLS signature (G1 point)
    /// @param pubkey The public key (G2 point)
    /// @return True if signature is valid
    function verifyBls(
        bytes memory message,
        Types.BN254G1Point memory signature,
        Types.BN254G2Point memory pubkey
    )
        internal
        view
        returns (bool)
    {
        // SECURITY INVARIANT: the BLS verification equation e(sig, G2) == e(H(m), pubkey)
        // must NOT be satisfiable by the identity (point at infinity). The pairing
        // precompile treats infinity as the pairing identity, so e(O, ·) = e(·, O) = 1.
        // An all-zero (signature, pubkey) pair therefore collapses BOTH sides of the
        // check to 1 and "verifies" ANY message — a universal forgery. Likewise an
        // infinity signature alone (e(O, G2) = 1) would verify the trivial pubkey, and
        // an infinity pubkey alone enables rogue-key style aggregation forgeries.
        // Reject degenerate (infinity) and malformed (off-curve / out-of-field) inputs
        // up front; only genuine subgroup elements may reach the pairing.
        if (isG1Infinity(signature) || isG2Infinity(pubkey)) revert DegenerateBlsInput();
        if (!isValidG1(signature)) revert InvalidG1Point();
        if (!isValidG2(pubkey)) revert InvalidG2Point();

        Types.BN254G1Point memory msgPoint = hashToG1(message);
        Types.BN254G2Point memory g2 = Types.BN254G2Point([G2_X0, G2_X1], [G2_Y0, G2_Y1]);
        return pairingCheck(signature, g2, msgPoint, pubkey);
    }

    /// @notice Verify an aggregated BLS signature
    /// @dev For aggregated signatures, we verify e(aggSig, G2) = e(H(msg), aggPubkey)
    /// @param message The signed message (must be same for all signers)
    /// @param aggregatedSignature The aggregated BLS signature
    /// @param aggregatedPubkey The aggregated public key
    /// @return True if signature is valid
    function verifyAggregatedBls(
        bytes memory message,
        Types.BN254G1Point memory aggregatedSignature,
        Types.BN254G2Point memory aggregatedPubkey
    )
        internal
        view
        returns (bool)
    {
        return verifyBls(message, aggregatedSignature, aggregatedPubkey);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MATH HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Compute modular square root using Tonelli-Shanks
    /// @dev Only works for p ≡ 3 (mod 4), which is true for BN254
    /// @param a The value to sqrt
    /// @return The square root (or garbage if not a QR)
    function sqrtMod(uint256 a) internal pure returns (uint256) {
        // For p ≡ 3 (mod 4): sqrt(a) = a^((p+1)/4)
        // P_MOD = 21888242871839275222246405745257275088696311157297823662689037894645226208583
        // (P_MOD + 1) / 4 = 5472060717959818805561601436314318772174077789324455915672259473661306552146
        // = 0x0c19139cb84c680a6e14116da060561765e05aa45a1c72a34f082305b61f3f52
        return expMod(a, 0x0c19139cb84c680a6e14116da060561765e05aa45a1c72a34f082305b61f3f52, P_MOD);
    }

    /// @notice Modular exponentiation
    /// @param base The base
    /// @param exponent The exponent
    /// @param modulus The modulus
    /// @return The result
    function expMod(uint256 base, uint256 exponent, uint256 modulus) internal pure returns (uint256) {
        uint256 result = 1;
        base = base % modulus;
        while (exponent > 0) {
            if (exponent % 2 == 1) {
                result = mulmod(result, base, modulus);
            }
            exponent = exponent >> 1;
            base = mulmod(base, base, modulus);
        }
        return result;
    }
}
