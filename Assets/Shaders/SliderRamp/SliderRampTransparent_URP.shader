// Mobile Games / Toon Ramp Transparent Shader (URP)
// Orijinal, sifirdan yazilmis toon/cel-shading shader (saydam/alpha-blend).
// Ucuncu parti asset koduna dayanmaz.

Shader "Mobile Games/Slider Ramp/URP/SliderRampTransparent"
{
    Properties
    {
        [Header(Base)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _HColor ("Highlight Color", Color) = (0.785,0.785,0.785,1.0)
        _SColor ("Shadow Color", Color) = (0.195,0.195,0.195,1.0)

        [Header(Ramp Settings)]
        _RampThreshold ("Ramp Threshold", Range(0,1)) = 0.5
        _RampSmooth ("Ramp Smoothing", Range(0.001,1)) = 0.1

        [Header(Transparency)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendTCP2 ("Blending Source", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlendTCP2 ("Blending Dest", Float) = 10
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            // Orijinaldeki gibi ZWrite icin herhangi bir override yok (varsayilan On),
            // Blend degerleri materyal uzerinden (enum) kontrol ediliyor.
            Blend [_SrcBlendTCP2] [_DstBlendTCP2]

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float3 positionWS  : TEXCOORD2;
                float  fogCoord    : TEXCOORD3;
            };

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Color;
                float4 _HColor;
                float4 _SColor;
                float  _RampThreshold;
                float  _RampSmooth;
                float  _SrcBlendTCP2;
                float  _DstBlendTCP2;
            CBUFFER_END

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs posIn = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normIn = GetVertexNormalInputs(IN.normalOS);

                OUT.positionHCS = posIn.positionCS;
                OUT.positionWS  = posIn.positionWS;
                OUT.normalWS    = normIn.normalWS;
                OUT.uv          = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.fogCoord    = ComputeFogFactor(posIn.positionCS.z);

                return OUT;
            }

            half4 Frag(Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half3 albedo = texColor.rgb * _Color.rgb;
                half alpha = texColor.a * _Color.a;

                Light mainLight = GetMainLight(TransformWorldToShadowCoord(IN.positionWS));
                float NdotL = saturate(dot(normalWS, mainLight.direction));
                float atten = mainLight.shadowAttenuation * mainLight.distanceAttenuation;
                NdotL *= atten;

                float rampFactor = smoothstep(
                    _RampThreshold - _RampSmooth * 0.5,
                    _RampThreshold + _RampSmooth * 0.5,
                    NdotL
                );
                half3 rampColor = lerp(_SColor.rgb, _HColor.rgb, rampFactor);

                half3 finalColor = albedo * mainLight.color.rgb * rampColor;
                finalColor += albedo * SampleSH(normalWS) * 0.3;
                finalColor = MixFog(finalColor, IN.fogCoord);

                return half4(finalColor, alpha);
            }
            ENDHLSL
        }

        // Not: orijinal shader'da "addshadow" keyword'u kullanilmadigi icin
        // (surface pragma'sinda yoktu), bu saydam varyant gölge düsürmüyor.
        // Bu, orijinal davranisla birebir eslesiyor - bilerek ShadowCaster
        // pass'i eklenmedi.
    }

    FallBack "Universal Render Pipeline/Lit"
}
