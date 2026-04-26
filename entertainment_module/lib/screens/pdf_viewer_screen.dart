import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// ==========================================
// 1. DOMAIN & DATA LAYER (Clean Architecture)
// ==========================================

/// Abstract repository outlining what the app needs to do
abstract class PdfRepository {
  Future<File> getCachedPdf(String url);
}


class PdfRepositoryImpl implements PdfRepository {
  @override
  Future<File> getCachedPdf(String url) async {

    return await DefaultCacheManager().getSingleFile(url);
  }
}

// ==========================================
// 2. PRESENTATION LAYER: BLOC (State Management)
// ==========================================

// --- Events ---
abstract class PdfEvent {}

class LoadPdfEvent extends PdfEvent {
  final String url;
  LoadPdfEvent(this.url);
}

// --- States ---
abstract class PdfState {}

class PdfInitial extends PdfState {}

class PdfLoading extends PdfState {}

class PdfLoaded extends PdfState {
  final File pdfFile;
  PdfLoaded(this.pdfFile);
}

class PdfError extends PdfState {
  final String errorMessage;
  PdfError(this.errorMessage);
}

// --- BLoC ---
class PdfBloc extends Bloc<PdfEvent, PdfState> {
  final PdfRepository pdfRepository;

  PdfBloc({required this.pdfRepository}) : super(PdfInitial()) {
    on<LoadPdfEvent>(_onLoadPdf);
  }

  Future<void> _onLoadPdf(LoadPdfEvent event, Emitter<PdfState> emit) async {
    emit(PdfLoading());
    try {
     
      final file = await pdfRepository.getCachedPdf(event.url);
      emit(PdfLoaded(file));
    } catch (e) {
      emit(PdfError("Failed to load PDF. Please check your internet."));
    }
  }
}

// ==========================================
// 3. PRESENTATION LAYER: UI (View)
// ==========================================

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      
      create: (context) => PdfBloc(pdfRepository: PdfRepositoryImpl())
        ..add(LoadPdfEvent(pdfUrl)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1B5E20),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocBuilder<PdfBloc, PdfState>(
          builder: (context, state) {
            if (state is PdfLoading || state is PdfInitial) {
              
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
              );
            } 
            else if (state is PdfLoaded) {
              return SfPdfViewer.file(
                state.pdfFile,
                canShowScrollHead: false, 
                canShowScrollStatus: false,
              );
            } 
            else if (state is PdfError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    state.errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}