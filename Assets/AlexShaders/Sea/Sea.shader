Shader "PGATR/Sea"
{
    Properties
    {
        [Header(Teselacion y Desplazamiento)]
        _TessellationUniform("Tessellation Level", Range(1, 64)) = 4
        _DisplacementMap ("Displacement Map", 2D) = "gray" {}
        _DisplacementStrength ("Displacement Strength", Range(0, 2)) = 0.5
        _MainColor("Main Color", Color) = (0.1,0.3,0.5,1)
        
        [Header(Wireframe)]
        [Toggle] _ShowWireframe("Show Wireframe", Float) = 1

        [Header(Oleaje)]
        _WaveSpeed("Wave Speed", Range(0, 5)) = 2.5

        [Header(Level Of Detail)]
        [Toggle] _EnableLOD("Enable LOD", Float) = 1
        _ClosestDetail("Closest", Range(1, 64)) = 32
        _FurthestDetail("Furthest", Range(1, 64)) = 4
    }

    SubShader
    {
        Tags {             
            "RenderType"="Transparent" 
            "Queue"="Transparent" 
        }
        LOD 200

        Pass
        {
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma hull hull
            #pragma domain domain
            #pragma geometry geom
            #pragma target 4.6

            #include "UnityCG.cginc"

            //Propiedades de la Teselacion y Desplazamiento
            float _TessellationUniform;
            sampler2D _DisplacementMap;
            float4 _DisplacementMap_ST;
            float _DisplacementStrength;
            fixed4 _MainColor;
            
            //Propiedades del "Wireframe"
            float _ShowWireframe;

            //Propiedades del Oleaje
            float _WaveSpeed;

            //Propiedades del LOD
            float _EnableLOD;
            float _ClosestDetail;
            float _FurthestDetail;

            struct vertexInput {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct vertexControl {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float displacementHeight : TEXCOORD1;
            };

            struct geometryOutput {
                float4 pos : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float3 barycentricCoordinates : TEXCOORD1;
                float displacementHeight : TEXCOORD2;
            };

            struct TessellationFactors {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            vertexControl vert(vertexInput v)
            {
                vertexControl o;
                o.vertex = v.vertex;
                o.normal = v.normal;
                o.uv = v.uv;
                return o;
            }

            TessellationFactors patchConstantFunction(InputPatch<vertexControl, 3> patch)
            {
                TessellationFactors f;

                float3 localPos = (patch[0].vertex.xyz + patch[1].vertex.xyz + patch[2].vertex.xyz) / 3.0;
                float3 worldPos = mul(unity_ObjectToWorld, float4(localPos, 1.0)).xyz;
                float3 camPos = _WorldSpaceCameraPos;
                float distanceToCam = 1 / distance(worldPos, camPos);

                float tessellationValue = _TessellationUniform;

                if(_EnableLOD > 0.5){
                    tessellationValue *= distanceToCam;
                    tessellationValue = clamp(tessellationValue, _FurthestDetail, _ClosestDetail);
                }

                f.edge[0] = tessellationValue;
                f.edge[1] = tessellationValue;
                f.edge[2] = tessellationValue;
                f.inside = tessellationValue;
                return f;
            }

            [UNITY_domain("tri")]
            [UNITY_outputcontrolpoints(3)]
            [UNITY_outputtopology("triangle_cw")]
            [UNITY_partitioning("integer")]
            [UNITY_patchconstantfunc("patchConstantFunction")]
            vertexControl hull(InputPatch<vertexControl, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            [UNITY_domain("tri")]
            vertexOutput domain(TessellationFactors factors, OutputPatch<vertexControl, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                vertexControl v;
                
                #define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) v.fieldName = \
                    patch[0].fieldName * barycentricCoordinates.x + \
                    patch[1].fieldName * barycentricCoordinates.y + \
                    patch[2].fieldName * barycentricCoordinates.z;

                MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
                MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
                MY_DOMAIN_PROGRAM_INTERPOLATE(uv)

                //Aplicar desplazamiento
                float2 transformedUV = TRANSFORM_TEX(v.uv, _DisplacementMap);
                float baseDisplacement = tex2Dlod(_DisplacementMap, float4(transformedUV, 0, 0)).r;
                
                //Oscilacion del oleaje
                float oscillation = sin(_Time.y * _WaveSpeed * 2.0 + baseDisplacement * 10.0);
                float displacement = baseDisplacement * oscillation * _DisplacementStrength;

                v.vertex.y += displacement * _DisplacementStrength;

                vertexOutput o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = transformedUV;
                o.displacementHeight = displacement;
                return o;
            }

            [maxvertexcount(3)]
            void geom(triangle vertexOutput input[3], inout TriangleStream<geometryOutput> triStream)
            {
                geometryOutput o;
                
                //Primer vertice
                o.pos = input[0].vertex;
                o.normal = input[0].normal;
                o.uv = input[0].uv;
                o.barycentricCoordinates = float3(1, 0, 0);
                o.displacementHeight = input[0].displacementHeight;
                triStream.Append(o);
                
                //Segundo vertice
                o.pos = input[1].vertex;
                o.normal = input[1].normal;
                o.uv = input[1].uv;
                o.barycentricCoordinates = float3(0, 1, 0);
                o.displacementHeight = input[1].displacementHeight;
                triStream.Append(o);
                
                //Tercer vertice
                o.pos = input[2].vertex;
                o.normal = input[2].normal;
                o.uv = input[2].uv;
                o.barycentricCoordinates = float3(0, 0, 1);
                o.displacementHeight = input[2].displacementHeight;
                triStream.Append(o);
            }

            fixed4 frag(geometryOutput i) : SV_Target
            {
                fixed4 col = _MainColor;

                float heightFactor = saturate(i.displacementHeight); // Asegura que esta entre 0 y 1
                col.rgb *= lerp(0.5, 1.5, heightFactor); 
                
                //Calculo del "Wireframe"
                if (_ShowWireframe > 0.5) {
                    float3 barycentricCoordinates = i.barycentricCoordinates;
                    float closest = min(min(barycentricCoordinates.x, barycentricCoordinates.y), barycentricCoordinates.z);
                    float wireWidth = 0.05;
                    float wire = smoothstep(wireWidth * 0.5, wireWidth, closest);
                    col = lerp(fixed4(0, 0, 0, 1), col, wire);
                }
                
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}