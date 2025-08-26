Shader "Custom/InstanceVegetable"
{
    Properties
    {
        [NoScaleOffset]_MainTex ("Base Color (RGB) Alpha(A)", 2D) = "white" {}
        _Color   ("Tint", Color) = (1,1,1,1)

        // 金属度/光滑度（可切换用贴图或常量）
        _Metallic ("Metallic", Range(0,1)) = 0
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
        _MetallicGlossMap ("Metallic(R) Smoothness(A)", 2D) = "black" {}

        // 法线、AO 等可按需添加
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _OcclusionMap ("Occlusion (G)", 2D) = "white" {}

        // —— 你的弯曲/风参数（可复用现有的）——
        _NoiseTex ("Noise", 2D) = "gray" {}
        _NoiseTiling ("Noise Tiling", Vector) = (1, 1, 1, 1)
        _NoisePannerSpeed("Noise Panner Speed", Vector) = (0.05, 0.03, 0, 0)

        _DefaultBending("MB Default Bending", Float) = 0
        _WindDirDeg ("Wind Dir", Range(0,360)) = 0
        _WindDirOffset("Wind Dir Offset", Range(0 , 180)) = 20
        _Amp ("Bend Amplitude", Float) = 1.2
        _AmplitudeOffset("MB Amplitude Offset", Float) = 2
        _Freq ("Bend Frequency", Float) = 1.1
        _FrequencyOffset("MB Frequency Offset", Float) = 0
        _Phase ("Bend Phase", Float) = 1.0
        _MaxHeight ("Max Height", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200
        Cull Off
        ZWrite Off

        CGPROGRAM
        #include "UnityShaderVariables.cginc"
        #pragma target 4.5

        #pragma multi_compile_instancing
        #pragma surface surf Standard fullforwardshadows vertex:vertexDataFunc alpha:fade
        #pragma instancing_options procedural:setup

        #include "UnityCG.cginc"
        #include "UnityInstancing.cginc"

        struct Input
        {
            float2 uv_MainTex;
            float2 uv_MetallicGlossMap;
            float2 uv_BumpMap;
            float2 uv_OcclusionMap;
        };

        uniform sampler2D _MainTex;
        uniform sampler2D _MetallicGlossMap;
        uniform sampler2D _BumpMap;
        uniform sampler2D _OcclusionMap;
        uniform sampler2D _NoiseTex;
        uniform float4 _Color;
        uniform float _Metallic;
        uniform float _Smoothness;
        uniform float4 _NoiseTiling;
        uniform float4 _NoisePannerSpeed;
        uniform float _WindDirDeg;
        uniform float _WindDirOffset;
        uniform float _Amp;
        uniform float _AmplitudeOffset;
        uniform float _Freq;
        uniform float _FrequencyOffset;
        uniform float _Phase;
        uniform float _DefaultBending;
        uniform float _MaxHeight;

        float3 RotateAroundAxis(float3 center, float3 original, float3 u, float angle)
        {
            original -= center;
            float C = cos(angle);
            float S = sin(angle);
            float t = 1 - C;
            float m00 = t * u.x * u.x + C;
            float m01 = t * u.x * u.y - S * u.z;
            float m02 = t * u.x * u.z + S * u.y;
            float m10 = t * u.x * u.y + S * u.z;
            float m11 = t * u.y * u.y + C;
            float m12 = t * u.y * u.z - S * u.x;
            float m20 = t * u.x * u.z - S * u.y;
            float m21 = t * u.y * u.z + S * u.x;
            float m22 = t * u.z * u.z + C;
            float3x3 finalMatrix = float3x3(m00, m01, m02, m10, m11, m12, m20, m21, m22);
            return mul(finalMatrix, original) + center;
        }

        void vertexDataFunc(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            UNITY_SETUP_INSTANCE_ID(v);

            float MB_WindDirection870 = _WindDirDeg;
            float MB_WindDirectionOffset1373 = _WindDirOffset;
            float3 objToWorld1645 = mul(unity_ObjectToWorld, float4(float3(0,0,0), 1)).xyz;
            float2 appendResult1506 = (float2(objToWorld1645.x , objToWorld1645.z));
            float2 WorldSpaceUVs1638 = appendResult1506;
            float2 AnimatedNoiseTilling1639 = (_NoiseTiling).zw;
            float2 panner1643 = (0.1 * _Time.y * _NoisePannerSpeed + float2(0,0));
            float4 AnimatedWorldNoise1344 = tex2Dlod(_NoiseTex, float4(((WorldSpaceUVs1638 * AnimatedNoiseTilling1639) + panner1643), 0, 0.0));
            float temp_output_1584_0 = radians(((MB_WindDirection870 + (MB_WindDirectionOffset1373 * (-1.0 + ((AnimatedWorldNoise1344).r - 0.0) * (1.0 - -1.0) / (1.0 - 0.0)))) * -1.0));
            float3 appendResult1587 = (float3(cos(temp_output_1584_0) , 0.0 , sin(temp_output_1584_0)));
            float3 worldToObj1646 = mul(unity_WorldToObject, float4(appendResult1587, 1)).xyz;
            float3 worldToObj1647 = mul(unity_WorldToObject, float4(float3(0,0,0), 1)).xyz;
            float3 normalizeResult1581 = normalize((worldToObj1646 - worldToObj1647));
            float3 MB_RotationAxis1420 = normalizeResult1581;
            float MB_Amplitude880 = _Amp;
            float MB_AmplitudeOffset1356 = _AmplitudeOffset;
            float2 StaticNoileTilling1640 = (_NoiseTiling).xy;
            float4 StaticWorldNoise1340 = tex2Dlod(_NoiseTex, float4((WorldSpaceUVs1638 * StaticNoileTilling1640), 0, 0.0));
            float3 objToWorld1649 = mul(unity_ObjectToWorld, float4(float3(0,0,0), 1)).xyz;
            float MB_Frequency873 = _Freq;
            float MB_FrequencyOffset1474 = _FrequencyOffset;
            float MB_Phase1360 = _Phase;
            float MB_DefaultBending877 = _DefaultBending;
            float3 ase_vertex3Pos = v.vertex.xyz;
            float MB_MaxHeight1335 = _MaxHeight;
            float MB_RotationAngle97 = radians(((((MB_Amplitude880 + (MB_AmplitudeOffset1356 * (StaticWorldNoise1340).r)) * sin((((objToWorld1649.x + objToWorld1649.z) + (_Time.y * (MB_Frequency873 + (MB_FrequencyOffset1474 * (StaticWorldNoise1340).r)))) * MB_Phase1360))) + MB_DefaultBending877) * (ase_vertex3Pos.y / MB_MaxHeight1335)));
            float3 appendResult1558 = (float3(0.0 , ase_vertex3Pos.y , 0.0));
            float3 rotatedValue1567 = RotateAroundAxis(appendResult1558, ase_vertex3Pos, MB_RotationAxis1420, MB_RotationAngle97);
            float3 rotatedValue1565 = RotateAroundAxis(float3(0,0,0), rotatedValue1567, MB_RotationAxis1420, MB_RotationAngle97);
            float3 LocalVertexOffset1045 = ((rotatedValue1565 - ase_vertex3Pos) * step(0.01 , ase_vertex3Pos.y));
            v.vertex.xyz += LocalVertexOffset1045;
            v.vertex.w = 1;
        }

        #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
            StructuredBuffer<float4x4> positionBuffer;
        #endif




        void setup()
        {
        #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
            unity_ObjectToWorld = positionBuffer[unity_InstanceID];
            unity_WorldToObject = unity_ObjectToWorld;
            unity_WorldToObject._14_24_34 *= -1;
            unity_WorldToObject._11_22_33 = 1.0f / unity_WorldToObject._11_22_33;
        #endif
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float4 base = tex2D(_MainTex, IN.uv_MainTex) * _Color;

            // 金属/粗糙（从图或常量）
            float4 mr = tex2D(_MetallicGlossMap, IN.uv_MetallicGlossMap);
            float metallic = lerp(_Metallic, mr.r, step(0.001, mr.a + mr.r)); // 有贴图就用贴图
            float smooth   = lerp(_Smoothness, mr.a, step(0.001, mr.a));

            // 法线、AO（可选）
            float3 normalTS = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
            o.Normal = normalTS;

            float ao = tex2D(_OcclusionMap, IN.uv_OcclusionMap).g;

            o.Albedo     = base.rgb;
            o.Metallic   = metallic;
            o.Smoothness = smooth;
            o.Occlusion  = ao;
            o.Alpha      = base.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
