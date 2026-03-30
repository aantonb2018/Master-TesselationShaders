Shader "PGATR/Seagulls"
{
    Properties
    {
        _BodyTex ("Textura Cuerpo", 2D) = "white" {}
        _LeftWingTex ("Textura Ala Izquierda", 2D) = "white" {}
        _RightWingTex ("Textura Ala Derecha", 2D) = "white" {}
        _Size ("Tamaño", Range(0.1, 2.0)) = 0.5
        _FlapSpeed ("Velocidad Aleteo", Range(0.0, 5.0)) = 1.0
        _FlapAmount ("Intensidad Aleteo", Range(0.0, 1.0)) = 0.3
        _Rotation ("Rotación", Range(0, 360)) = 0
        _WingAttachFactor ("Unión del Ala", Range(0.0, 1.0)) = 0.7
        _WingHeightOffset ("Altura del Ala", Range(-1.0, 1.0)) = 0.0
        [Toggle] _DebugBodyColor ("Depurar Cuerpo", Int) = 0
        [Toggle] _DebugWingColor ("Depurar Alas", Int) = 0
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
            sampler2D _LeftWingTex;
            float4 _LeftWingTex_ST;
            sampler2D _RightWingTex;
            float4 _RightWingTex_ST;

            float _Size;
            float _FlapSpeed;
            float _FlapAmount;
            float _Rotation;
            float _WingAttachFactor;
            float _WingHeightOffset;
            int _DebugBodyColor;
            int _DebugWingColor;

            v2g vert(appdata v)
            {
                v2g o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.flapOffset = sin(_Time.y + v.vertex.x * 100.0);
                return o;
            }

            [maxvertexcount(18)]
            void geom(point v2g IN[1], inout TriangleStream<g2f> stream)
            {
                float3 center = IN[0].worldPos.xyz;
                float flap = pow(sin(_Time.y * _FlapSpeed + IN[0].flapOffset), 2) * _FlapAmount;

                float angle = radians(_Rotation);
                float cosA = cos(angle);
                float sinA = sin(angle);
                // rotacion en x
                float3 right = float3(1, 0, 0);
                float3 up = float3(0, cosA, sinA);
                float3 forward = float3(0, -sinA, cosA);

                float bodyWidth = _Size * 0.3;
                float wingLength = _Size * 0.7;
                float wingAttachHeight = bodyWidth * 1;

                g2f o;
                o.color = fixed4(1, 1, 1, 1);

                float3 bodyVerts[4] = {
                    center - right * bodyWidth*0.5  - up * bodyWidth ,
                    center + right * bodyWidth*0.5  - up * bodyWidth ,
                    center + right * bodyWidth*0.5  + up * bodyWidth ,
                    center - right * bodyWidth*0.5  + up * bodyWidth 
                };

                float2 bodyUVs[4] = {
                    float2(0.0, 0.0),
                    float2(1.0, 0.0),
                    float2(1.0, 1.0),
                    float2(0.0, 1.0)
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

                float flapAngle = flap * radians(45.0);
                float cosAL = cos(flapAngle);
                float sinAL = sin(flapAngle);
                float wingOffset = bodyWidth * _WingAttachFactor;

                float3 anchorLeftTop    = center - right * wingOffset + up * (wingAttachHeight + _WingHeightOffset);
                float3 anchorLeftBottom = center - right * wingOffset - up * (wingAttachHeight - _WingHeightOffset);

                float3 tipLeftTop       = center - right * (wingOffset + wingLength) + up * (wingAttachHeight + 0.05);
                float3 tipLeftBottom    = center - right * (wingOffset + wingLength) - up * (wingAttachHeight + 0.05);

                float3 toTop    = tipLeftTop - anchorLeftTop;
                float3 toBottom = tipLeftBottom - anchorLeftBottom;
                // rotacion en z
                float3 rotatedTop = anchorLeftTop + float3(
                    toTop.x * cosAL - toTop.y * sinAL,
                    toTop.x * sinAL + toTop.y * cosAL,
                    toTop.z
                );

                float3 rotatedBottom = anchorLeftBottom + float3(
                    toBottom.x * cosAL - toBottom.y * sinAL,
                    toBottom.x * sinAL + toBottom.y * cosAL,
                    toBottom.z
                );

                float3 leftWingVerts[4] = {
                    anchorLeftTop,
                    anchorLeftBottom,
                    rotatedTop,
                    rotatedBottom
                };

                float2 leftWingUVs[4] = {
                    float2(1.0, 1.0),
                    float2(1.0, 0.0),
                    float2(0.0, 1.0),
                    float2(0.0, 0.0)
                };

                int leftIndices[6] = { 0, 1, 2, 2, 1, 3 };

                for (int i = 0; i < 6; i++)
                {
                    int idx = leftIndices[i];
                    o.pos = UnityWorldToClipPos(leftWingVerts[idx]);
                    o.uv = TRANSFORM_TEX(leftWingUVs[idx], _LeftWingTex);
                    o.partID = 1.0;
                    stream.Append(o);
                }
                stream.RestartStrip();

                float flapAngleR = -flap * radians(45.0);
                float cosAR = cos(flapAngleR);
                float sinAR = sin(flapAngleR);

                float3 anchorRightTop    = center + right * wingOffset + up * (wingAttachHeight + _WingHeightOffset);
                float3 anchorRightBottom = center + right * wingOffset - up * (wingAttachHeight - _WingHeightOffset);

                float3 tipRightTop       = center + right * (wingOffset + wingLength) + up * (wingAttachHeight + 0.05);
                float3 tipRightBottom    = center + right * (wingOffset + wingLength) - up * (wingAttachHeight + 0.05);

                float3 toTopR    = tipRightTop - anchorRightTop;
                float3 toBottomR = tipRightBottom - anchorRightBottom;

                float3 rotatedTopR = anchorRightTop + float3(
                    toTopR.x * cosAR - toTopR.y * sinAR,
                    toTopR.x * sinAR + toTopR.y * cosAR,
                    toTopR.z
                );

                float3 rotatedBottomR = anchorRightBottom + float3(
                    toBottomR.x * cosAR - toBottomR.y * sinAR,
                    toBottomR.x * sinAR + toBottomR.y * cosAR,
                    toBottomR.z
                );

                float3 rightWingVerts[4] = {
                    anchorRightTop,
                    anchorRightBottom,
                    rotatedTopR,
                    rotatedBottomR
                };

                float2 rightWingUVs[4] = {
                    float2(0.0, 1.0),
                    float2(0.0, 0.0),
                    float2(1.0, 1.0),
                    float2(1.0, 0.0)
                };

                int rightIndices[6] = { 0, 1, 2, 2, 1, 3 };

                for (int i = 0; i < 6; i++)
                {
                    int idx = rightIndices[i];
                    o.pos = UnityWorldToClipPos(rightWingVerts[idx]);
                    o.uv = TRANSFORM_TEX(rightWingUVs[idx], _RightWingTex);
                    o.partID = 2.0;
                    stream.Append(o);
                }
            }

            fixed4 frag(g2f IN) : SV_Target
            {
                fixed4 col;

                if (_DebugBodyColor == 1 && IN.partID == 0.0)
                {
                    return fixed4(1, 0, 0, 1);
                }
                else if (_DebugWingColor == 1 && (IN.partID == 1.0 || IN.partID == 2.0))
                {
                    return fixed4(0, 0, 1, 1);
                }
                else
                {
                    if (IN.partID == 0.0)
                        col = tex2D(_BodyTex, IN.uv) * IN.color;
                    else if (IN.partID == 1.0)
                        col = tex2D(_LeftWingTex, IN.uv) * IN.color;
                    else
                        col = tex2D(_RightWingTex, IN.uv) * IN.color;

                    clip(col.a - 0.1);
                    return col;
                }
            }
            ENDCG
        }
    }
}

