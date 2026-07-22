// Toony Colors Pro+Mobile 2 - URP Conversion
// Original: (c) 2014-2020 Jean Moreno
// Converted from Built-in Render Pipeline (CGPROGRAM/#pragma surface) to
// Universal Render Pipeline (HLSLPROGRAM, explicit forward pass).
//
// Same shading model as the original:
//   - Toon ramp lighting (Highlight/Shadow color blended via NdotL)
//   - Blinn-Phong specular, stepped for a toon look
// Given a different shader name (…/URP/SliderRampSpecular) so it can live
// side-by-side with the original Built-in shader without name collisions.

Shader "Mobile Games/Slider Ramp/URP/SliderRampSpecular"
{
    Properties
    {
        [Header(Base Properties)]
        _Color ("Color", Color) = (1,1,1,1)
        _HColor ("Highlight Color", Color) = (0.785,0.785,0.785,1.0)
        _SColor ("Shadow Color", Color) = (0.195,0.195,0.195,1.0)
        _MainTex ("Main Texture", 2D) = "white" {}

        [Space(10)]
        [Header(Ramp Settings)]
        _RampThreshold ("Ramp Threshold", Range(0,1)) = 0.5
        _RampSmooth ("Ramp Smoothing", Range(0.001,1)) = 0.1

        [Space(10)]
        [Header(Specular)]
        _SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
        _Smoothness ("Size", Float) = 0.2
        _SpecSmooth ("Smoothness", Range(0,1)) = 0.05
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                half4  _Color;
                half4  _HColor;
                half4  _SColor;
                half   _RampThreshold;
                half   _RampSmooth;
                half4  _SpecColor;
                half   _Smoothness;
                half   _SpecSmooth;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS   : TEXCOORD2;
                float4 shadowCoord: TEXCOORD3;
                float  fogCoord   : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS);

                OUT.positionCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;
                OUT.normalWS = normalInput.normalWS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.shadowCoord = GetShadowCoord(vertexInput);
                OUT.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);

                return OUT;
            }

            // Toon ramp + stepped specular for a given light (main or additional)
            half3 ToonLighting(Light light, half3 normalWS, half3 viewDirWS, half3 albedo)
            {
                half attenuation = light.shadowAttenuation * light.distanceAttenuation;

                half NdotL = saturate(dot(normalWS, light.direction));
                half ramp = smoothstep(_RampThreshold - _RampSmooth * 0.5,
                                        _RampThreshold + _RampSmooth * 0.5, NdotL);
                ramp *= attenuation;

                // Same blend as the original: shadow intensity through _SColor's alpha
                half3 shadowColor = lerp(_HColor.rgb, _SColor.rgb, _SColor.a);
                half3 rampColor = lerp(shadowColor, _HColor.rgb, ramp);

                // Blinn-Phong specular, stepped for a toon look
                half3 halfDir = normalize(light.direction + viewDirWS);
                half NdotH = saturate(dot(normalWS, halfDir));
                half spec = pow(NdotH, _Smoothness * 128.0) * 2.0;
                spec = smoothstep(0.5 - _SpecSmooth * 0.5, 0.5 + _SpecSmooth * 0.5, spec);
                spec *= attenuation;

                half3 color = albedo * light.color * rampColor;
                color += light.color * _SpecColor.rgb * spec;
                return color;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half3 albedo = texColor.rgb * _Color.rgb;
                half alpha = texColor.a * _Color.a;

                half3 normalWS = normalize(IN.normalWS);
                half3 viewDirWS = normalize(GetWorldSpaceViewDir(IN.positionWS));

                Light mainLight = GetMainLight(IN.shadowCoord);
                half3 color = ToonLighting(mainLight, normalWS, viewDirWS, albedo);

                // Baked/indirect ambient (rough equivalent of the original's gi.indirect.diffuse)
                color += albedo * SampleSH(normalWS);

            #ifdef _ADDITIONAL_LIGHTS
                uint additionalLightsCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < additionalLightsCount; lightIndex++)
                {
                    Light light = GetAdditionalLight(lightIndex, IN.positionWS);
                    color += ToonLighting(light, normalWS, viewDirWS, albedo);
                }
            #endif

                color = MixFog(color, IN.fogCoord);

                return half4(color, alpha);
            }
            ENDHLSL
        }

        // Needed so this object casts shadows for other objects
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            float3 _LightDirection;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings ShadowPassVertex(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

            #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
            #endif

                OUT.positionCS = positionCS;
                return OUT;
            }

            half4 ShadowPassFragment(Varyings IN) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }

        // Needed for depth texture / SSAO / depth-based effects
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings DepthOnlyVertex(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half4 DepthOnlyFragment(Varyings IN) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }
    }

    Fallback Off
}
