// Mobile Games / Toon Ramp Cutout Shader (URP)
// Orijinal, sifirdan yazilmis toon/cel-shading shader (alpha cutout).
// Kenarlari duzensiz gorunmesi gereken duz plane objeler icin
// (cali, yaprak, kayalik siluet gibi) - texture'in alpha kanalindaki
// seffaf bolgeler yuzeyi "keser".

Shader "Mobile Games/Toon Ramp/ToonRampCutout"
{
    Properties
    {
        [Header(Base)]
        _MainTex ("Main Texture (RGBA)", 2D) = "white" {}
        _Color ("Tint Color", Color) = (1,1,1,1)

        [Header(Ramp Colors)]
        _HColor ("Highlight Color", Color) = (0.785,0.785,0.785,1.0)
        _SColor ("Shadow Color", Color) = (0.195,0.195,0.195,1.0)

        [Header(Ramp Settings)]
        _RampThreshold ("Ramp Threshold", Range(0,1)) = 0.5
        _RampSmooth ("Ramp Smoothness", Range(0.001,1)) = 0.1

        [Header(Alpha Cutout)]
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5

        [Header(Rendering)]
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode (Off = iki taraftan görünür)", Float) = 0
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
                OUT.uv          = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.fogCoord    = ComputeFogFactor(posIn.positionCS.z);

                return OUT;
            }

            half4 Frag(Varyings IN, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                // Cift tarafli render icin: arka yuzdeyken normali ters cevir,
                // aksi halde arkadan bakildiginda yuzey siyah/hatali aydinlanir.
                float3 normalWS = normalize(IN.normalWS);
                normalWS = isFrontFace ? normalWS : -normalWS;

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);

                // --- ALPHA CUTOUT: burasi kritik kisim ---
                // Texture'in alpha kanali _Cutoff esiginin altindaysa piksel
                // tamamen atiliyor (yok sayiliyor) - boylece dikdortgen plane,
                // texture'daki organik siluete gore "kesilmis" gibi gorunuyor.
                clip(texColor.a * _Color.a - _Cutoff);

                half3 albedo = texColor.rgb * _Color.rgb;

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

                return half4(finalColor, 1);
            }
            ENDHLSL
        }

        // Golge dusurme - cutout alpha testini burada da tekrarliyoruz,
        // yoksa yaprak/cali seklindeki obje hala dikdortgen bir golge dusurur.
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

            // ApplyShadowBias URP surumune gore farkli dosyalarda tanimli
            // olabildigi icin (surum bagimliligi hata verebiliyor), bias
            // hesabini burada kendimiz, disariya bagimli olmadan yapiyoruz.
            float3 ApplyShadowBiasManual(float3 positionWS, float3 normalWS, float3 lightDirWS)
            {
                float invNdotL = 1.0 - saturate(dot(lightDirWS, normalWS));
                float scale = invNdotL * 0.01; // sabit normal-bias miktari
                positionWS = lightDirWS * 0.005 + positionWS;
                positionWS = normalWS * scale + positionWS;
                return positionWS;
            }

            Varyings ShadowVert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
                float3 biasedPositionWS = ApplyShadowBiasManual(positionWS, normalWS, _LightDirection);

                float4 positionCS = TransformWorldToHClip(biasedPositionWS);
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                OUT.positionHCS = positionCS;
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
