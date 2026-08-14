import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Se lanza cuando una llamada a la API falla (red, timeout o el servidor
/// responde con un error). El mensaje ya viene listo para mostrar al usuario.
class GarageApiException implements Exception {
  GarageApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cliente HTTP para el backend de reserva de plazas (FastAPI + Supabase).
///
/// El plan gratuito de Render "duerme" el servicio si lleva un rato sin
/// tráfico, y la primera petición que lo despierta puede tardar hasta unos
/// 50 segundos en responder. Por eso el timeout es tan largo: no es que la
/// petición vaya a tardar siempre eso, es el margen para ese caso concreto.
class GarageApi {
  GarageApi({http.Client? client, this.baseUrl = _defaultBaseUrl})
    : _client = client ?? http.Client();

  static const _defaultBaseUrl = 'https://vibecodelearn-park.onrender.com';
  static const _timeout = Duration(seconds: 60);

  final http.Client _client;
  final String baseUrl;

  Future<List<Map<String, dynamic>>> obtenerPlazas() {
    return _peticion(
      () => _client.get(Uri.parse('$baseUrl/plazas')),
      (respuesta) =>
          (jsonDecode(respuesta.body) as List<dynamic>)
              .cast<Map<String, dynamic>>(),
    );
  }

  Future<Map<String, dynamic>> ocuparPlaza(int id, String nombre) {
    return _peticion(
      () => _client.put(
        Uri.parse('$baseUrl/plazas/$id/ocupar'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': nombre}),
      ),
      (respuesta) => jsonDecode(respuesta.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> liberarPlaza(int id) {
    return _peticion(
      () => _client.put(Uri.parse('$baseUrl/plazas/$id/liberar')),
      (respuesta) => jsonDecode(respuesta.body) as Map<String, dynamic>,
    );
  }

  /// Envía la petición, la somete al timeout y traduce cualquier fallo
  /// (timeout, sin red, error del servidor) a un único tipo de excepción
  /// para que quien llame no tenga que distinguir entre varios.
  Future<T> _peticion<T>(
    Future<http.Response> Function() enviar,
    T Function(http.Response respuesta) parsear,
  ) async {
    http.Response respuesta;
    try {
      respuesta = await enviar().timeout(_timeout);
    } on TimeoutException {
      throw GarageApiException(
        'El servidor no respondió a tiempo. Puede que esté arrancando '
        'tras estar inactivo — vuelve a intentarlo en unos segundos.',
      );
    } catch (_) {
      throw GarageApiException('No se pudo conectar con el servidor.');
    }
    if (respuesta.statusCode >= 400) {
      throw GarageApiException(
        'El servidor respondió con un error (${respuesta.statusCode}): '
        '${_detalleDelError(respuesta)}',
      );
    }
    return parsear(respuesta);
  }

  /// FastAPI devuelve los errores como `{"detail": "..."}`. Si el cuerpo no
  /// tiene ese formato (por ejemplo, una página de error de Render en vez
  /// de una respuesta de nuestra API), se muestra el texto tal cual.
  String _detalleDelError(http.Response respuesta) {
    try {
      final cuerpo = jsonDecode(respuesta.body);
      if (cuerpo is Map<String, dynamic> && cuerpo['detail'] != null) {
        return cuerpo['detail'].toString();
      }
    } catch (_) {
      // El cuerpo no era JSON válido; se usa tal cual más abajo.
    }
    return respuesta.body;
  }
}
