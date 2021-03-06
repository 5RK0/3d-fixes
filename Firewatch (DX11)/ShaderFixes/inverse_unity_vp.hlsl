#include "unity_cbuffers.hlsl"

cbuffer UnityPerFrame : register(b11) {
	struct UnityPerFrame PerFrame;
}

RWBuffer<float4> OutputInverseVP : register(u0);

float4 inverse_transpose_parallel(matrix m, uint pos)
{
	uint3 idx;
	float4 tmp;

	idx = pos < uint3(1, 2, 3) ? uint3(1, 2, 3) : uint3(0, 1, 2);
	float add = pos % 2 == 0 ? 1.0 : -1.0;

	tmp = m[idx.x].yxxx*(add*m[idx.y].zwyz*m[idx.z].wzwy - add*m[idx.y].wzwy*m[idx.z].zwyz)
	    + m[idx.x].zzyy*(add*m[idx.y].wxwx*m[idx.z].ywxz - add*m[idx.y].ywxz*m[idx.z].wxwx)
	    + m[idx.x].wwwz*(add*m[idx.y].yzxy*m[idx.z].zxyx - add*m[idx.y].zxyx*m[idx.z].yzxy);
	return tmp / determinant(m);
}

[numthreads(4, 1, 1)]
void main(uint3 tid: SV_DispatchThreadID)
{
	// We're using a transposing version of the matrix inverse function.
	// This may seem wrong at first glance, but it works so long as the
	// input matrix is declared in "column_major" order, because DX11
	// stores "column_major" matrices with the entries across each *row* in
	// each of the register components (this is the opposite of DX9), but
	// when we write it to the output buffer we are writing the entries
	// down each *column* to each of the components in a register. When
	// this is read back in the destination shader, it will have been
	// effectively transposed back to the correct order.
	//
	// If the input matrix is declared to be in "row_major" order, just lie
	// and declare it "column_major" so the compiler will do the right
	// thing, or add a transpose() around the input matrix (transposing the
	// output would require a synchronisation between threads - better to
	// avoid that and just transpose the input, which should be
	// mathematically equivalent). Note that if you legitimately wanted a
	// transposed output for some reason you could save some (13)
	// instructions in this shader by doing the opposite of this advice.
	OutputInverseVP[tid.x] = inverse_transpose_parallel(PerFrame.unity_MatrixV, tid.x);
}
