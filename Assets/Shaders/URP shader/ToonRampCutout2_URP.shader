// Mobile Games / Toon Ramp Cutout Shader (URP)
// Orijinal, sifirdan yazilmis toon/cel-shading shader (alpha cutout + specular).
// Ucuncu parti asset koduna dayanmaz.

Shader "Mobile Games/Toon Ramp/ToonRampCutout"
{
    Properties
    {
        [Header(Base)]
        _MainTex ("Main Texture (RGBA)", 2D) = "white" {}
        _Color ("Tint Color", Color) = (1,1,1,1)

        [Header(Ramp Colors)]
        _HColor ("Highlight Color", Color) = (0.785,0.785,0.785,1.0)
        // Shadow Color'in alpha kanali golge yuzeyi gor. etkisini kontrol eder
        [HDR] _SColor ("Shadow Color", Color) = (0.195,0.195,0.195,1.0)

        [Header(Ramp Settings)]
        _RampThreshold ("Ramp Threshold", Range(0,1)) = 0.5
        _RampSmooth ("Ramp Smoothing", Range(0.001,1)) = 0.1

        [Header(Specular)]
        _SpecColor ("Specular Color", Color) = (0.5,0.5,0.5,1)
        _SpecSize ("Size", Float) = 0.2
        _SpecSmooth ("Smoothness", Range(0,1)) = 0.35

        [Header(Alpha Cutout)]
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5

        [Header(Rendering)]
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode (Off = iki taraftan gorunur)", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "TransparentCutout"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "AlphaTest"
            "IgnoreProjector" = "True"
        }
        LOD 200

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Cull [_CullMode]

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
                float3 viewDirWS   : TEXCOORD3;
                float  fogCoord    : TEXCOORD4;
            };

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Color;
                float4 _HColor;
                float4 _SColor;
                float  _RampThreshold;
                float  _RampSmooth;
                float4 _SpecColor;
                float  _SpecSize;
                float  _SpecSmooth;
                float  _Cutoff;
            CBUFFER_END

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs posIn = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normIn = GetVertexNormalInputs(IN.normalOS);

                OUT.positionHCS = posIn.positionCS;
                OUT.positionWS  = posIn.positionWS;
                OUT.normalWS    = normIn.normalWS;
                OUT.viewDirWS   = GetWorldSpaceViewDir(posIn.positionWS);
                OUT.uv          = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.fogCoord    = ComputeFogFactor(posIn.positionCS.z);

                return OUT;
            }

            half4 Frag(Varyings IN, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                // Cift tarafli render icin normali duzelt
                float3 normalWS  = normalize(IN.normalWS);
                normalWS = isFrontFace ? normalWS : -normalWS;
                float3 viewDirWS = normalize(IN.viewDirWS);

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);

                // Alpha cutout
                clip(texColor.a * _Color.a - _Cutoff);

                half3 albedo = texColor.rgb * _Color.rgb;

                // Toon ramp
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(IN.positionWS));
                float NdotL = saturate(dot(normalWS, mainLight.direction));
                float atten  = mainLight.shadowAttenuation * mainLight.distanceAttenuation;
                NdotL *= atten;

                float rampFactor = smoothstep(
                    _RampThreshold - _RampSmooth * 0.5,
                    _RampThreshold + _RampSmooth * 0.5,
                    NdotL
                );

                // Shadow Color alpha -> golge yuzeyi goru. etkisi (orijinaldeki gibi)
                half4 shadowColor = lerp(_HColor, _SColor, _SColor.a);
                half3 rampColor   = lerp(shadowColor.rgb, _HColor.rgb, rampFactor);

                half3 finalColor = albedo * mainLight.color.rgb * rampColor;

                // Ambient
                finalColor += albedo * SampleSH(normalWS) * 0.3;

                // Specular - Blinn-Phong, toon tarzinda keskin
                float3 halfVec  = normalize(mainLight.direction + viewDirWS);
                float  NdotH    = saturate(dot(normalWS, halfVec));
                float  specPow  = max(_SpecSize * 128.0, 1.0);
                float  spec     = smoothstep(
                    0.5 - _SpecSmooth * 0.5,
                    0.5 + _SpecSmooth * 0.5,
                    pow(NdotH, specPow)
                ) * atten;
                finalColor += mainLight.color.rgb * _SpecColor.rgb * spec;

                finalColor = MixFog(finalColor, IN.fogCoord);

                return half4(finalColor, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_CullMode]

            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_shadowcaster

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Color;
                float4 _HColor;
                float4 _SColor;
                float  _RampThreshold;
                float  _RampSmooth;
                float4 _SpecColor;
                float  _SpecSize;
                float  _SpecSmooth;
                float  _Cutoff;
            CBUFFER_END

            float3 _LightDirection;

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
            };

            float3 ApplyShadowBiasManual(float3 posWS, float3 normWS, float3 lightDir)
            {
                float invNdotL = 1.0 - saturate(dot(lightDir, normWS));
                posWS += lightDir  * 0.005;
                posWS += normWS    * invNdotL * 0.01;
                return posWS;
            }

            Varyings ShadowVert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                float3 biasedWS   = ApplyShadowBiasManual(positionWS, normalWS, _LightDirection);

                float4 posCS = TransformWorldToHClip(biasedWS);
                #if UNITY_REVERSED_Z
                    posCS.z = min(posCS.z, posCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    posCS.z = max(posCS.z, posCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                OUT.positionHCS = posCS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                return OUT;
            }

            half4 ShadowFrag(Varyings IN) : SV_Target
            {
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                clip(texColor.a * _Color.a - _Cutoff);
                return 0;
            }
            ENDHLSL
        }
    }

    FallBack "Universal Render Pipeline/Lit"
}
