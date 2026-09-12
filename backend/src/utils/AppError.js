/**
 * Erro de aplicacao com status HTTP.
 * Permite que controllers sinalizem 400/404 sem acoplar-se ao Express.
 */
'use strict';

class AppError extends Error {
  constructor(status, message, details = undefined) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.details = details;
  }

  static badRequest(message, details) {
    return new AppError(400, message, details);
  }

  static notFound(message) {
    return new AppError(404, message);
  }

  static unauthorized(message) {
    return new AppError(401, message);
  }

  static forbidden(message) {
    return new AppError(403, message);
  }

  static conflict(message) {
    return new AppError(409, message);
  }
}

module.exports = AppError;
