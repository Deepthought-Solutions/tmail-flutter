import 'dart:async';

import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/app_logger.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tmail_ui_user/features/composer/domain/exceptions/compose_email_exception.dart';
import 'package:tmail_ui_user/features/composer/domain/state/generate_email_state.dart';
import 'package:tmail_ui_user/features/composer/domain/state/send_email_state.dart';
import 'package:tmail_ui_user/features/composer/domain/usecases/create_new_and_send_email_interactor.dart';
import 'package:tmail_ui_user/features/composer/presentation/model/create_email_request.dart';
import 'package:tmail_ui_user/main/exceptions/remote/unknown_remote_exception.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

typedef OnCancelSendingEmailAction = Function({CancelToken? cancelToken});

class SendingMessageDialogView extends StatefulWidget {

  final CreateEmailRequest createEmailRequest;
  final CreateNewAndSendEmailInteractor createNewAndSendEmailInteractor;
  final OnCancelSendingEmailAction? onCancelSendingEmailAction;
  final CancelToken? cancelToken;

  const SendingMessageDialogView({
    super.key,
    required this.createEmailRequest,
    required this.createNewAndSendEmailInteractor,
    this.onCancelSendingEmailAction,
    this.cancelToken,
  });

  @override
  State<SendingMessageDialogView> createState() => _SendingMessageDialogViewState();
}

class _SendingMessageDialogViewState extends State<SendingMessageDialogView> {

  StreamSubscription? _streamSubscription;
  final ValueNotifier<String> _statusText = ValueNotifier('Envoi en cours...');
  final ValueNotifier<bool> _isError = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _streamSubscription = widget.createNewAndSendEmailInteractor
      .execute(
        createEmailRequest: widget.createEmailRequest,
        cancelToken: widget.cancelToken
      )
      .listen(
        _handleDataStream,
        onError: _handleErrorStream
      );
  }

  void _handleDataStream(dartz.Either<Failure, Success> newState) {
    newState.fold(
      (failure) {
        if (failure is SendEmailFailure || failure is GenerateEmailFailure) {
          popBack(result: failure);
        }
      },
      (success) {
        if (success is SendEmailSuccess) {
          popBack(result: success);
        } else {
          _statusText.value = _getStatusMessage(success);
        }
      }
    );
  }

  void _handleErrorStream(Object error, StackTrace stackTrace) {
    logWarning('_SendingMessageDialogViewState::_handleErrorStream: Exception = $error');
    if (error is UnknownRemoteException && error.error is List<SendingEmailCanceledException>) {
      popBack(result: SendEmailFailure(exception: SendingEmailCanceledException()));
    } else {
      popBack(result: SendEmailFailure(exception: error));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Toast-style widget at bottom of screen instead of modal dialog
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade800,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _statusText,
                    builder: (context, status, _) {
                      return Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusMessage(Success success) {
    if (success is GenerateEmailLoading) {
      return AppLocalizations.of(context).sendingMessage;
    } else if (success is SendEmailLoading) {
      return AppLocalizations.of(context).sendingMessage;
    }
    return AppLocalizations.of(context).sendingMessage;
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _statusText.dispose();
    _isError.dispose();
    super.dispose();
  }
}
