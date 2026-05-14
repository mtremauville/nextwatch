import { application } from "controllers/application"
import TmdbSearchController from "controllers/tmdb_search_controller"
import ModalController from "controllers/modal_controller"
import CoverflowController from "controllers/coverflow_controller"

application.register("tmdb-search", TmdbSearchController)
application.register("modal", ModalController)
application.register("coverflow", CoverflowController)
