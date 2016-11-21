/*****************************************************************************
 * ==> interpolated_fragment.glsl -------------------------------------------*
 *****************************************************************************
 * Description : Fragment shader program, used to draw and interpolate model *
 * Developer   : Jean-Milost Reymond                                         *
 *****************************************************************************/

#version 150

// texture sampler input
uniform sampler2D qr_sColorMap;

// input from vertex program
in vec4 qr_fColor;
in vec2 qr_fTexCoord;

void main()
{
    // set final color
    gl_FragColor = qr_fColor * texture2D(qr_sColorMap, qr_fTexCoord);
}