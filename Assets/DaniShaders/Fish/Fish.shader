Shader "PGATR/Fish"
{
    Properties
    {
        _BodyTex ("Textura Cuerpo", 2D) = "white" {}
        _TailTex ("Textura Cola", 2D) = "white" {}
        _Size ("Tamaño", Range(0.1, 2.0)) = 0.5
        _FlapSpeed ("Velocidad Aleteo", Range(0.0, 5.0)) = 1.0
        _FlapAmount ("Intensidad Aleteo", Range(0.0, 1.0)) = 0.3
        _Rotation ("Rotación", Range(0, 360)) = 0
        _TailAttachFactor ("Unión de la Cola", Range(0.0, 1.0)) = 0.7
        _TailHeightOffset ("Altura de la Cola", Range(-1.0, 1.0)) = 0.0
        [Toggle] _DebugBodyColor ("Depurar Cuerpo", Int) = 0
        [Toggle] _DebugTailColor ("Depurar Cola", Int) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2g
            {
                float4 worldPos : TEXCOORD0;
                float flapOffset : TEXCOORD1;
            };

            struct g2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;
                nointerpolation float partID : TEXCOORD1;
            };

            sampler2D _BodyTex;
            float4 _BodyTex_ST;
            sampler2D _TailTex;
            float4 _TailTex_ST;

            float _Size;
            float _FlapSpeed;
            float _FlapAmount;
            float _Rotation;
            float _TailAttachFactor;
            float _TailHeightOffset;
            int _DebugBodyColor;
            int _DebugTailColor;

            v2g vert(appdata v)
            {
                v2g o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.flapOffset = sin(_Time.y + v.vertex.x * 100.0); // offset para el aleteo
                return o;
            }

            [maxvertexcount(18)]
            void geom(point v2g IN[1], inout TriangleStream<g2f> stream)
            {
                float3 center = IN[0].worldPos.xyz;
                float flap = sin(_Time.y * _FlapSpeed + IN[0].flapOffset) * _FlapAmount; // movimiento

                float angle = radians(_Rotation);
                float cosA = cos(angle);
                float sinA = sin(angle);
                // rotacion en x
                float3 right = float3(1, 0, 0);
                float3 up = float3(0, cosA, sinA);
                float3 forward = float3(0, -sinA, cosA);

                // cuerpo y la cola
                float bodyWidth = _Size * 0.4;
                float bodyHeight = _Size * 0.6; 
                float tailLength = _Size * 0.5; 
                float tailAttachHeight = bodyHeight * 0.9;

                g2f o;
                o.color = fixed4(1, 1, 1, 1);

                // ---- CUERPO DEL PEZ (Quad) ----
                float3 bodyVerts[4] = {
                    center - right * bodyWidth * 1 - up * bodyHeight * 1,
                    center + right * bodyWidth * 1 - up * bodyHeight * 1,
                    center + right * bodyWidth * 1 + up * bodyHeight * 1,
                    center - right * bodyWidth * 1 + up * bodyHeight * 1
                };

                float2 bodyUVs[4] = {
                    float2(1.0, 0.0),
                    float2(0.0, 0.0),
                    float2(0.0, 1.0),
                    float2(1.0, 1.0)
                };

                int bodyIndices[6] = { 0, 1, 2, 2, 3, 0 };

                for (int i = 0; i < 6; i++)
                {
                    int idx = bodyIndices[i];
                    o.pos = UnityWorldToClipPos(bodyVerts[idx]);
                    o.uv = TRANSFORM_TEX(bodyUVs[idx], _BodyTex);
                    o.partID = 0.0;
                    stream.Append(o);
                }
                stream.RestartStrip();

                // ---- COLA DEL PEZ (Quad) ----
                float flapAngle = flap * radians(45.0);  // angulo de aleteo
                float cosAL = cos(flapAngle);
                float sinAL = sin(flapAngle);
                float tailOffset = bodyWidth * _TailAttachFactor;
                // parte al cuerpo
                float3 anchorLeftTop    = center - right * tailOffset + up * (tailAttachHeight + _TailHeightOffset);
                float3 anchorLeftBottom = center - right * tailOffset - up * (tailAttachHeight - _TailHeightOffset);
                // parte a la punta
                float3 tipLeftTop       = center - right * (tailOffset + tailLength) + up * (tailAttachHeight );
                float3 tipLeftBottom    = center - right * (tailOffset + tailLength) - up * (tailAttachHeight );
                // vector del cuerrpo a la punta
                float3 toTop    = tipLeftTop - anchorLeftTop;
                float3 toBottom = tipLeftBottom - anchorLeftBottom;
                // rotaciones para ambas puntas en y
                float3 rotatedTop = anchorLeftTop + float3(
                    toTop.x * cosAL - toTop.z * sinAL,
                    toTop.y,
                    toTop.x * sinAL + toTop.z * cosAL
                );
                
                float3 rotatedBottom = anchorLeftBottom + float3(
                    toBottom.x * cosAL - toBottom.z * sinAL,
                    toBottom.y,
                    toBottom.x * sinAL + toBottom.z * cosAL
                );

                float3 tailVerts[4] = {
                    anchorLeftTop,
                    anchorLeftBottom,
                    rotatedTop,
                    rotatedBottom
                };

                float2 tailUVs[4] = {
                    float2(0.0, 1.0),
                    float2(0.0, 0.0),
                    float2(1.0, 1.0),
                    float2(1.0, 0.0)
                };

                int tailIndices[6] = { 0, 1, 2, 2, 1, 3 };

                for (int i = 0; i < 6; i++)
                {
                    int idx = tailIndices[i];
                    o.pos = UnityWorldToClipPos(tailVerts[idx]);
                    o.uv = TRANSFORM_TEX(tailUVs[idx], _TailTex);
                    o.partID = 1.0;
                    stream.Append(o);
                }
                stream.RestartStrip();
            }

            fixed4 frag(g2f IN) : SV_Target
            {
                fixed4 col;

                if (_DebugBodyColor == 1 && IN.partID == 0.0)
                {
                    return fixed4(1, 0, 0, 1);
                }
                else if (_DebugTailColor == 1 && IN.partID == 1.0)
                {
                    return fixed4(0, 0, 1, 1);
                }
                else
                {
                    if (IN.partID == 0.0)
                        col = tex2D(_BodyTex, IN.uv) * IN.color;
                    else
                        col = tex2D(_TailTex, IN.uv) * IN.color;

                    clip(col.a - 0.1);
                    return col;
                }
            }
            ENDCG
        }
    }
}
