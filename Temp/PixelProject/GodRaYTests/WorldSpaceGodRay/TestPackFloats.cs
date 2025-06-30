using System;
using Godot;

public partial class TestPackFloats : Node2D
{
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		float originalA = 0.33f;
		float originalB = 1.77f;
		float originalC = 2.55f;

		float packed = PackTwoFloats(originalA, originalB);
		(float unpackedA, float unpackedB) unpackedTwo = UnpackTwoFloats(packed);
		var (unpackedA, unpackedB) = UnpackTwoFloats(packed);

		Log.Debug($"2 FLOATS: Original A: {originalA} - Original B: {originalB} - Unpacked A: {unpackedTwo.unpackedA} - Unpacked B: {unpackedTwo.unpackedB}");

		float packed3 = PackThreeFloats(originalA, originalB, originalC);
		(float unpackedA, float unpackedB, float unpackedC) unpackedThree = UnpackThreeFloats(packed3);

		Log.Debug($"3 FLOATS: Original A: {originalA} - Original B: {originalB} - Original C: {originalC}  - Unpacked A: {unpackedThree.unpackedA} - Unpacked B: {unpackedThree.unpackedB} - Unpacked C: {unpackedThree.unpackedC}");


	}

	// Packs two float values (0.0–1.0) into a single float
	public static float PackTwoFloats(float a, float b)
	{
		uint a16 = (uint)(Math.Clamp(a, 0f, 1f) * 65535.0f); // 16-bit
		uint b16 = (uint)(Math.Clamp(b, 0f, 1f) * 65535.0f);
		uint packed = (a16 << 16) | b16;
		return packed / 4294967296.0f; // = 2^32
	}

	float PackThreeFloats(float a, float b, float c)
	{
		// Clamp to [0.0, 1.0]
		uint a10 = (uint)(Math.Clamp(a, 0f, 1f) * 1023.0f); // 10-bit
		uint b10 = (uint)(Math.Clamp(b, 0f, 1f) * 1023.0f);
		uint c10 = (uint)(Math.Clamp(c, 0f, 1f) * 1023.0f);
		uint packed = (a10 << 20) | (b10 << 10) | c10;
		return packed / 4294967296.0f; // Convert to 0.0–1.0 float
	}

	// Unpacks two float values (0.0–1.0) from a single packed float
	public static (float, float) UnpackTwoFloats(float packedFloat)
	{
		uint packed = (uint)(packedFloat * 4294967296.0f);
		uint a16 = (packed >> 16) & 0xFFFF;
		uint b16 = packed & 0xFFFF;
		return (a16 / 65535.0f, b16 / 65535.0f);
	}

	public static (float, float, float) UnpackThreeFloats(float packedValue)
	{
		// Convert the packed float [0,1) back to a 32-bit uint
		uint packed = (uint)(packedValue * 4294967296.0f); // 2^32

		// Extract each 10-bit value
		uint a10 = (packed >> 20) & 0x3FF; // Top 10 bits
		uint b10 = (packed >> 10) & 0x3FF; // Middle 10 bits
		uint c10 = packed & 0x3FF;         // Bottom 10 bits

		// Normalize back to [0.0, 1.0]
		float a = a10 / 1023.0f;
		float b = b10 / 1023.0f;
		float c = c10 / 1023.0f;

		return (a, b, c);
	}

	//SHADER CODE TO UNPACK
	// float packed_value = INSTANCE_CUSTOM.w; // or a uniform, or COLOR.a //Get it from Shader
	// vec2 unpacked = unpack_two_floats(packed_value);
	// float floatA = unpacked.x;
	// float floatB = unpacked.y;

	// vec2 unpack_two_floats(float packed)
	// {
	// 	float scaled = packed * 4294967296.0; // 2^32
	// 	float high = floor(scaled / 65536.0);
	// 	float low = mod(scaled, 65536.0);
	// 	return vec2(high, low) / 65535.0;
	// }

	// vec3 unpack_three_floats(float packed)
	// {
	// 	float scaled = packed * 4294967296.0; // scale to 32-bit integer range
	// 	float a = floor(scaled / 1048576.0); // 2^20 = 1048576
	// 	float b = floor(mod(scaled, 1048576.0) / 1024.0);
	// 	float c = mod(scaled, 1024.0);

	// 	return vec3(a, b, c) / 1023.0; // normalize to [0.0, 1.0]
	// }

	//UNPACK AND RESET VALUE (assumes max float 4)
	// float packed = INSTANCE_CUSTOM.x;
	// vec3 unpacked = unpack_three_floats(packed);
	// unpacked *= 4.0; // MAX_VALUE used during normalization

}
